# frozen_string_literal: true

require_relative "audio_renderer"
require_relative "constants"
require_relative "export_formats"
require_relative "export_progress"
require_relative "file_encoder"

module DrumMachine
  # SampleLoader — ported from the class of the same name in upstream's
  # src/services/audio_export_service.py.
  #
  # Upstream decodes every sample by shelling out to ffmpeg. All ten bundled
  # samples are plain PCM WAV, so this port reads those itself and only falls
  # back to ffmpeg for the compressed formats a user can drop in (.mp3, .ogg,
  # .flac). Samples come back as a flat Array of Floats, stereo interleaved, at
  # the export sample rate — the shape AudioBuffer mixes.
  class SampleLoader
    CHANNELS = AudioBuffer::CHANNELS

    # Bits per sample this reader understands, mapped to the unpack directive
    # and the full-scale value that normalises it to -1.0..1.0.
    PCM_FORMATS = {
      8  => ["C*", 128.0],
      16 => ["s<*", 32_768.0],
      32 => ["l<*", 2_147_483_648.0],
    }.freeze

    WAVE_FORMAT_PCM = 1
    WAVE_FORMAT_IEEE_FLOAT = 3
    WAVE_FORMAT_EXTENSIBLE = 0xFFFE

    attr_reader :samples

    def initialize(sample_rate = 44_100)
      @sample_rate = sample_rate
      @samples = {}
    end

    def load_samples(drum_parts)
      @samples = {}
      drum_parts.each do |part|
        if part.file_available?
          @samples[part.id] = load_sample(part.file_path) || fallback
        end
      end
      @samples
    end

    def clear_samples
      @samples = {}
    end

    private

      def fallback = Array.new(Constants::DEFAULT_FALLBACK_SAMPLE_SIZE.inject(:*), 0.0)

      def load_sample(path)
        if File.extname(path).downcase == ".wav"
          read_wav(path)
        else
          decode_with_ffmpeg(path)
        end
      rescue StandardError => e
        warn "drum-machine: could not load #{path}: #{e.message}"
        nil
      end

      # Walks the RIFF chunks for "fmt " and "data"; anything else (LIST, fact,
      # a trailing id3 tag) is skipped by its declared length.
      def read_wav(path)
        File.binread(path).then do |data|
          unless data.byteslice(0, 4) == "RIFF" && data.byteslice(8, 4) == "WAVE"
            raise ArgumentError, "not a RIFF/WAVE file"
          end

          riff_chunks(data).then do |chunks|
            decode_pcm(chunks[:fmt], chunks[:data])
          end
        end
      end

      def riff_chunks(data)
        {}.tap do |chunks|
          position = 12
          while position + 8 <= data.bytesize
            data.byteslice(position, 4).then do |chunk_id|
              data.byteslice(position + 4, 4).unpack1("V").then do |length|
                case chunk_id
                when "fmt " then chunks[:fmt] = data.byteslice(position + 8, length)
                when "data" then chunks[:data] = data.byteslice(position + 8, length)
                end
                position += 8 + length + (length % 2)
              end
            end
          end
        end
      end

      def decode_pcm(fmt, payload)
        if fmt.nil? || payload.nil?
          raise ArgumentError, "WAVE file has no fmt or data chunk"
        end

        fmt.unpack("vvVVvv").then do |audio_format, channels, rate, _byte_rate, _align, bits|
          resample(
            to_stereo(raw_samples(payload, audio_format, bits), channels),
            rate,
          )
        end
      end

      def raw_samples(payload, audio_format, bits)
        case
        when audio_format == WAVE_FORMAT_IEEE_FLOAT && bits == 32
          payload.unpack("e*")
        when bits == 24
          unpack24(payload)
        when [WAVE_FORMAT_PCM, WAVE_FORMAT_EXTENSIBLE].include?(audio_format) && PCM_FORMATS.key?(bits)
          PCM_FORMATS[bits].then do |directive, full_scale|
            payload.unpack(directive).map { |value| (bits == 8 ? value - 128 : value) / full_scale }
          end
        else
          raise ArgumentError, "unsupported WAVE encoding: format #{audio_format}, #{bits} bits"
        end
      end

      # 24-bit samples have no pack directive, so they are sign-extended by
      # hand, three bytes at a time, little-endian.
      def unpack24(payload)
        payload.unpack("C*").each_slice(3).map do |low, mid, high|
          ((high << 16) | (mid << 8) | low).then do |value|
            (value >= 0x800000 ? value - 0x1000000 : value) / 8_388_608.0
          end
        end
      end

      def to_stereo(frames, channels)
        case channels
        when CHANNELS then frames
        when 1 then frames.flat_map { |value| [value, value] }
        else frames.each_slice(channels).flat_map { |frame| frame.first(CHANNELS) }
        end
      end

      # Nearest-neighbour, which is all a one-shot drum sample needs: every
      # bundled sample is already at the export rate, so this only runs for a
      # dropped-in file recorded at another.
      def resample(interleaved, rate)
        if rate == @sample_rate || rate.to_i.zero?
          interleaved
        else
          (interleaved.length / CHANNELS).then do |source_frames|
            ((source_frames * @sample_rate) / rate).then do |target_frames|
              Array.new(target_frames * CHANNELS) do |index|
                interleaved[(((index / CHANNELS) * rate / @sample_rate) * CHANNELS) + (index % CHANNELS)] || 0.0
              end
            end
          end
        end
      end

      def decode_with_ffmpeg(path)
        IO.popen(
          [
            "ffmpeg",
            "-i", path,
            "-f", "f32le",
            "-ac", CHANNELS.to_s,
            "-ar", @sample_rate.to_s,
            "-loglevel", "quiet",
            "-",
          ],
          "rb",
        ).then do |io|
          begin
            io.read.unpack("e*")
          ensure
            io.close
          end
        end
      end
  end

  # AudioExportService — ported from upstream's
  # src/services/audio_export_service.py.
  #
  # Loads the samples fresh, renders the pattern and hands the buffer to the
  # encoder. Runs on the export thread, so it touches no widget.
  class AudioExportService
    SAMPLE_RATE = 44_100

    attr_reader :format_registry

    def initialize(window)
      @window = window
      @sample_loader = SampleLoader.new(SAMPLE_RATE)
      @audio_renderer = AudioRenderer.new({}, SAMPLE_RATE)
      @format_registry = ExportFormatRegistry.new
      @audio_encoder = AudioEncoder.new(@format_registry)
    end

    # Returns true on success. A pattern with no active beats raises, which the
    # task turns into the "Export failed" toast.
    def export_audio(
      drum_parts_state,
      bpm,
      file_path,
      progress_callback:,
      repeat_count: 1,
      metadata: nil,
      export_task: nil
    )
      begin
        progress_callback.call(ExportPhase::PREPARING)

        @sample_loader.load_samples(@window.sound_service.drum_part_manager.all_parts)
        @audio_renderer.update_samples(@sample_loader.samples)
        validate_pattern(drum_parts_state)

        progress_callback.call(ExportPhase::RENDERING)
        @audio_renderer.render_pattern(
          drum_parts_state,
          bpm,
          @window.drum_machine_service.total_beats,
          repeat_count,
        ).then do |audio_buffer|
          progress_callback.call(ExportPhase::SAVING)
          @audio_encoder.encode_to_file(
            audio_buffer.buffer,
            SAMPLE_RATE,
            file_path,
            metadata,
            export_task,
          )
        end

        true
      ensure
        @sample_loader.clear_samples
        @audio_renderer.clear_samples
      end
    end

    private

      def validate_pattern(drum_parts_state)
        drum_parts_state.each_value.any? { |beats| beats.each_value.any? { |active| active } }.then do |has_beats|
          unless has_beats
            raise ArgumentError, "no active beats in pattern"
          end
        end
      end
  end
end
