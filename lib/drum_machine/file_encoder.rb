# frozen_string_literal: true

require "English"
require_relative "export_formats"

module DrumMachine
  # AudioEncoder — ported from upstream's src/services/file_encoder.py.
  #
  # Upstream pipes the rendered float buffer into ffmpeg for every format,
  # including WAV. This port writes WAV itself — a RIFF header and the samples
  # are all it takes, and that keeps the one metadata-free format working on a
  # machine with no ffmpeg — and keeps upstream's ffmpeg pipe, argument for
  # argument, for MP3, FLAC and Ogg, where the encoder and the metadata tags
  # are the whole point.
  class AudioEncoder
    CHANNELS = 2
    BITS_PER_SAMPLE = 16
    WAV_EXTENSION = ".wav"

    def initialize(format_registry)
      @format_registry = format_registry
    end

    # The export task is passed through so a cancel can kill the encoder
    # mid-write, and so the service can tell a cancellation from a failure.
    def encode_to_file(audio_data, sample_rate, file_path, metadata = nil, export_task = nil)
      File.extname(file_path).downcase.then do |file_ext|
        @format_registry.get_format_by_extension(file_ext).then do |format_info|
          # WAV carries no tags, so its metadata is dropped rather than written.
          format_info.supports_metadata? ? metadata : nil
        end.then do |tags|
          if file_ext == WAV_EXTENSION
            write_wav(audio_data, sample_rate, file_path)
          else
            encode_with_ffmpeg(
              audio_data,
              sample_rate,
              file_path,
              tags,
              export_task,
            )
          end
        end
      end
    end

    private

      # 16-bit signed PCM, which is what every one of the four formats accepts
      # as input and what a .wav file is expected to hold.
      def pcm16(audio_data)
        audio_data.map { |value| (value.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
      end

      def float32(audio_data) = audio_data.map { |value| value.to_f }.pack("e*")

      def write_wav(audio_data, sample_rate, file_path)
        pcm16(audio_data).then do |pcm|
          File.binwrite(file_path, [riff_header(pcm.bytesize, sample_rate), pcm].join)
        end
      end

      def riff_header(data_size, sample_rate)
        (CHANNELS * BITS_PER_SAMPLE / 8).then do |block_align|
          [
            "RIFF",
            [36 + data_size].pack("V"),
            "WAVEfmt ",
            [16, 1, CHANNELS, sample_rate, sample_rate * block_align, block_align, BITS_PER_SAMPLE].pack("Vvv VVvv"),
            "data",
            [data_size].pack("V"),
          ].join
        end
      end

      # The same argv upstream builds: raw 32-bit float stereo on stdin, an
      # optional cover art input mapped as an attached picture, then the tags.
      def ffmpeg_command(sample_rate, file_path, metadata)
        [
          "ffmpeg",
          "-y",
          "-f", "f32le",
          "-ar", sample_rate.to_s,
          "-ac", CHANNELS.to_s,
          "-i", "-",
          *cover_art_arguments(metadata),
          "-map", "0:a",
          *cover_art_mapping(metadata),
          *metadata_arguments(metadata),
          file_path,
        ]
      end

      def encode_with_ffmpeg(audio_data, sample_rate, file_path, metadata, export_task)
        if export_task&.cancelled?
          nil
        else
          run_ffmpeg(ffmpeg_command(sample_rate, file_path, metadata), float32(audio_data), export_task)
        end
      end

      def run_ffmpeg(command, payload, export_task)
        IO.popen(command, "r+b", err: File::NULL).then do |io|
          export_task&.current_process = io.pid
          begin
            io.write(payload)
            io.close_write
            io.read
          ensure
            io.close
            export_task&.current_process = nil
          end
        end.then do
          if $CHILD_STATUS && !$CHILD_STATUS.success?
            raise "ffmpeg encoding failed with status #{$CHILD_STATUS.exitstatus}"
          end
        end
      end

      def cover_art?(metadata)
        metadata && metadata[:cover_art] && File.exist?(metadata[:cover_art])
      end

      def cover_art_arguments(metadata)
        cover_art?(metadata) ? ["-i", metadata[:cover_art]] : []
      end

      def cover_art_mapping(metadata)
        cover_art?(metadata) ? ["-map", "1:v", "-disposition:v:0", "attached_pic"] : []
      end

      def metadata_arguments(metadata)
        [].tap do |arguments|
          if metadata
            if metadata[:title]
              arguments.push("-metadata", "title=#{metadata[:title]}")
            end
            if metadata[:artist]
              arguments.push("-metadata", "artist=#{metadata[:artist]}")
            end
          end
        end
      end
  end
end
