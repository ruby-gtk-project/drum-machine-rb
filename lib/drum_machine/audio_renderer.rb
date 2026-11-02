# frozen_string_literal: true

require_relative "constants"

module DrumMachine
  # AudioBuffer — ported from the class of the same name in upstream's
  # src/services/audio_renderer.py.
  #
  # Upstream holds the mix in a numpy float32 array of shape (frames, 2). Ruby
  # has no numpy, so the buffer is a flat Array of Floats with the two channels
  # interleaved: frame n is at 2n and 2n+1. Everything downstream — the encoder
  # and the WAV writer — reads it in that order anyway.
  class AudioBuffer
    CHANNELS = 2
    PEAK = 0.95

    attr_reader :sample_rate, :buffer

    def initialize(sample_rate = 44_100)
      @sample_rate = sample_rate
      @buffer = nil
    end

    def create_buffer(duration_seconds)
      (duration_seconds * @sample_rate).to_i.then do |total_frames|
        @buffer = Array.new([total_frames, 0].max * CHANNELS, 0.0)
      end
    end

    # Mixes one sample in at a frame offset, clipped to the end of the buffer.
    def add_sample(sample_data, start_frame)
      @buffer.then do |target|
        if target.nil?
          warn "drum-machine: attempted to add a sample to an uninitialized buffer"
        else
          mix(target, sample_data, start_frame * CHANNELS)
        end
      end
    end

    def normalize
      @buffer.then do |target|
        if target.nil?
          warn "drum-machine: attempted to normalize an uninitialized buffer"
        else
          target.minmax.map(&:abs).max.then do |max_amplitude|
            if max_amplitude.positive?
              scale(target, PEAK / max_amplitude)
            end
          end
        end
      end
    end

    def frame_count = @buffer ? @buffer.length / CHANNELS : 0

    private

      def mix(target, sample_data, offset)
        [sample_data.length, target.length - offset].min.then do |count|
          index = 0
          while index < count
            target[offset + index] += sample_data[index]
            index += 1
          end
        end
      end

      def scale(target, factor)
        index = 0
        while index < target.length
          target[index] *= factor
          index += 1
        end
      end
  end

  # AudioRenderer — ported from upstream's src/services/audio_renderer.py.
  #
  # Lays each active beat's sample into one buffer at the time the tempo puts
  # it, repeats the whole pattern as many times as the dialog asks, and
  # normalises the result.
  class AudioRenderer
    def initialize(samples, sample_rate = 44_100)
      @samples = samples
      @sample_rate = sample_rate
    end

    def update_samples(samples)
      @samples = samples
    end

    def clear_samples
      @samples = {}
    end

    # The pattern's own length, plus however far the last sample rings on past
    # the end of it.
    def calculate_pattern_duration(drum_parts_state, bpm, repeat_count, total_beats)
      subdivisions_per_second(bpm).then do |subdivisions|
        (total_beats / subdivisions).then do |pattern_duration|
          [
            latest_sample_end_time(drum_parts_state, subdivisions),
            pattern_duration,
          ].max.then do |end_time|
            (pattern_duration * repeat_count) + (end_time - pattern_duration)
          end
        end
      end
    end

    def render_pattern(drum_parts_state, bpm, total_beats, repeat_count)
      AudioBuffer.new(@sample_rate).tap do |audio_buffer|
        audio_buffer.create_buffer(
          calculate_pattern_duration(
            drum_parts_state,
            bpm,
            repeat_count,
            total_beats,
          ),
        )

        subdivisions_per_second(bpm).then do |subdivisions|
          (@sample_rate / subdivisions).to_i.then do |frames_per_subdivision|
            (total_beats / subdivisions).then do |pattern_duration|
              repeat_count.times do |repeat|
                render_repeat(
                  drum_parts_state,
                  audio_buffer,
                  (repeat * pattern_duration * @sample_rate).to_i,
                  frames_per_subdivision,
                  total_beats,
                )
              end
            end
          end
        end

        audio_buffer.normalize
      end
    end

    private

      def subdivisions_per_second(bpm) = (bpm / 60.0) * Constants::GROUP_TOGGLE_COUNT

      def latest_sample_end_time(drum_parts_state, subdivisions)
        drum_parts_state.filter_map do |part_id, part_state|
          part_state.select { |_beat, active| active }.keys.max.then do |last_subdivision|
            if last_subdivision
              (last_subdivision / subdivisions) + sample_length_seconds(part_id)
            end
          end
        end.max || 0.0
      end

      def sample_length_seconds(part_id)
        (@samples[part_id]&.length).to_i.then do |interleaved|
          (interleaved / AudioBuffer::CHANNELS) / @sample_rate.to_f
        end
      end

      def render_repeat(drum_parts_state, audio_buffer, repeat_offset, frames_per_subdivision, total_beats)
        total_beats.times do |subdivision|
          add_subdivision_samples(
            drum_parts_state,
            audio_buffer,
            subdivision,
            repeat_offset + (subdivision * frames_per_subdivision),
          )
        end
      end

      def add_subdivision_samples(drum_parts_state, audio_buffer, subdivision, start_frame)
        drum_parts_state.each do |part_id, part_state|
          if part_state[subdivision]
            audio_buffer.add_sample(@samples[part_id] || fallback_sample, start_frame)
          end
        end
      end

      # A part whose file would not load mixes in as silence, the same length
      # upstream's np.zeros fallback is.
      def fallback_sample
        @fallback_sample ||= Array.new(Constants::DEFAULT_FALLBACK_SAMPLE_SIZE.inject(:*), 0.0)
      end
  end
end
