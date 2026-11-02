# frozen_string_literal: true

require_relative "constants"

module DrumMachine
  # PatternService — ported from upstream's src/services/pattern_service.py.
  #
  # Upstream reads and writes Standard MIDI Files with `mido`. There is no
  # `mido` for Ruby and no MIDI gem in this fork's bundle, so the reader and
  # writer below are spelled out: a drum pattern only ever needs one track of
  # note_on/note_off pairs plus a set_tempo, and both halves are small enough
  # to carry here rather than take on a dependency.
  #
  # The grid is a 16th-note grid, so a beat index is `ticks_per_beat / 4` ticks
  # from the start of the file — the same conversion mido's port does.
  class PatternService
    # mido's defaults, kept so a pattern written here round-trips through the
    # Python app byte-for-byte compatible.
    TICKS_PER_BEAT = 480
    MIDI_FORMAT = 1
    NOTE_VELOCITY = 100

    MICROSECONDS_PER_MINUTE = 60_000_000

    STATUS_NOTE_OFF = 0x80
    STATUS_NOTE_ON = 0x90
    META_PREFIX = 0xFF
    META_SET_TEMPO = 0x51
    META_END_OF_TRACK = 0x2F
    SYSEX_START = 0xF0
    SYSEX_ESCAPE = 0xF7

    # Bytes of data each voice-message status takes, keyed by its high nibble.
    VOICE_MESSAGE_LENGTHS = {
      0x80 => 2,
      0x90 => 2,
      0xA0 => 2,
      0xB0 => 2,
      0xC0 => 1,
      0xD0 => 1,
      0xE0 => 2,
    }.freeze

    # The window is passed in because both directions need the drum part
    # manager to map a part id to a MIDI note and back.
    def initialize(window)
      @window = window
    end

    # Writes the pattern as a one-track MIDI file. Chords — several parts on
    # the same beat — share one delta time, with the later notes at delta 0,
    # which is how upstream groups them.
    def save_pattern(file_path, drum_parts, bpm)
      File.binwrite(file_path, midi_file(track_bytes(pattern_events(drum_parts), bpm)))
    end

    # Reads a MIDI file back into the drum_parts_state shape
    # ({ part_id => { beat_index => true } }) and the file's tempo.
    def load_pattern(file_path)
      parse_file(File.binread(file_path)).then do |header, tracks|
        state = @window.drum_machine_service.create_empty_drum_parts_state
        bpm = Constants::DEFAULT_BPM

        tracks.each do |events|
          events.each do |event|
            case event[:type]
            when :set_tempo then bpm = MICROSECONDS_PER_MINUTE.fdiv(event[:tempo])
            when :note_on then record_note(state, event, header[:ticks_per_beat])
            end
          end
        end

        [state, bpm]
      end
    end

    private

      def record_note(state, event, ticks_per_beat)
        part_id_for_midi_note(event[:note]).then do |part_id|
          state[part_id] ||= {}
          state[part_id][beat_index(event[:ticks], ticks_per_beat)] = true
        end
      end

      def beat_index(absolute_ticks, ticks_per_beat)
        (absolute_ticks / (ticks_per_beat / 4.0)).round
      end

      def midi_note_for_part(part_id)
        @window.sound_service.drum_part_manager.get_part_by_id(part_id).then do |part|
          part&.midi_note_id || 0
        end
      end

      def part_id_for_midi_note(note)
        @window.sound_service.drum_part_manager.get_or_create_part_for_midi_note(note).id
      end

      # Every active toggle as { note:, beat: }, sorted by beat so the writer
      # can walk them in chronological order. Notes a part has no mapping for
      # (note 0) are dropped, as upstream does.
      def pattern_events(drum_parts)
        drum_parts.flat_map do |part_id, beats|
          midi_note_for_part(part_id).then do |note|
            if note.zero?
              []
            else
              beats.select { |_beat_index, active| active }
                   .map { |beat_index, _active| { note: note, beat: beat_index } }
            end
          end
        end.sort_by { |event| event[:beat] }
      end

      # MThd + one MTrk.
      def midi_file(track)
        [
          "MThd",
          [6].pack("N"),
          [MIDI_FORMAT, 1, TICKS_PER_BEAT].pack("n3"),
          "MTrk",
          [track.bytesize].pack("N"),
          track,
        ].join
      end

      def track_bytes(events, bpm)
        [
          meta_event(META_SET_TEMPO, [tempo_for(bpm)].pack("N")[1, 3]),
          note_events(events),
          meta_event(META_END_OF_TRACK, ""),
        ].join
      end

      def tempo_for(bpm) = (MICROSECONDS_PER_MINUTE / bpm.to_f).round

      # A 16th note long, the same duration upstream writes.
      def note_duration_ticks = TICKS_PER_BEAT / 4

      def note_events(events)
        @last_time_in_ticks = 0
        events.group_by { |event| event[:beat] }.map do |beat, group|
          chord_bytes(beat, group.map { |event| event[:note] })
        end.join
      end

      def chord_bytes(beat, notes)
        ((beat * TICKS_PER_BEAT) / 4).to_i.then do |absolute_ticks|
          (absolute_ticks - @last_time_in_ticks).then do |delta|
            @last_time_in_ticks = absolute_ticks + note_duration_ticks
            [
              voice_messages(
                STATUS_NOTE_ON,
                notes,
                NOTE_VELOCITY,
                delta,
              ),
              voice_messages(
                STATUS_NOTE_OFF,
                notes,
                0,
                note_duration_ticks,
              ),
            ].join
          end
        end
      end

      # The chord's first message carries the delta time, the rest follow at 0.
      def voice_messages(status, notes, velocity, first_delta)
        notes.each_with_index.map do |note, index|
          [
            variable_length(index.zero? ? first_delta : 0),
            [status, note, velocity].pack("C3"),
          ].join
        end.join
      end

      def meta_event(type, data)
        [
          variable_length(0),
          [META_PREFIX, type].pack("C2"),
          variable_length(data.bytesize),
          data,
        ].join
      end

      # MIDI variable-length quantity: seven bits per byte, high bit set on
      # every byte but the last.
      def variable_length(value)
        [value & 0x7F].then do |bytes|
          (value >> 7).then do |remainder|
            while remainder.positive?
              bytes.unshift((remainder & 0x7F) | 0x80)
              remainder >>= 7
            end
            bytes.pack("C*")
          end
        end
      end

      # --- reading -------------------------------------------------------

      # Returns [header_hash, array_of_event_arrays]. Chunks whose type is not
      # MTrk are skipped, which is what a reader is required to do.
      def parse_file(data)
        read_header(data).then do |header|
          [header, read_tracks(data, header[:header_end], header[:track_count])]
        end
      end

      def read_header(data)
        data.byteslice(0, 4).then do |magic|
          if magic == "MThd"
            data.byteslice(8, 6).unpack("n3").then do |_format, track_count, division|
              {
                ticks_per_beat: division.positive? ? division : TICKS_PER_BEAT,
                track_count:    track_count,
                header_end:     8 + data.byteslice(4, 4).unpack1("N"),
              }
            end
          else
            raise ArgumentError, "not a MIDI file: expected MThd, got #{magic.inspect}"
          end
        end
      end

      def read_tracks(data, offset, track_count)
        [].tap do |tracks|
          position = offset
          while tracks.length < track_count && position + 8 <= data.bytesize
            data.byteslice(position, 4).then do |chunk_type|
              data.byteslice(position + 4, 4).unpack1("N").then do |length|
                if chunk_type == "MTrk"
                  tracks << read_track(data.byteslice(position + 8, length))
                end
                position += 8 + length
              end
            end
          end
        end
      end

      # One track's events, each carrying its absolute tick position. Running
      # status (a data byte where a status byte was expected) is honoured.
      def read_track(bytes)
        [].tap do |events|
          position = 0
          ticks = 0
          status = nil

          while position < bytes.bytesize
            read_variable_length(bytes, position).then do |delta, after_delta|
              ticks += delta
              bytes.getbyte(after_delta).then do |byte|
                if byte >= 0x80
                  status = byte
                  position = after_delta + 1
                else
                  position = after_delta
                end
                position = read_event(
                  bytes,
                  position,
                  status,
                  ticks,
                  events,
                )
              end
            end
          end
        end
      end

      def read_event(bytes, position, status, ticks, events)
        case status
        when META_PREFIX then read_meta_event(
          bytes,
          position,
          ticks,
          events,
        )
        when SYSEX_START, SYSEX_ESCAPE then skip_sysex(bytes, position)
        else read_voice_event(
          bytes,
          position,
          status,
          ticks,
          events,
        )
        end
      end

      def read_meta_event(bytes, position, ticks, events)
        bytes.getbyte(position).then do |type|
          read_variable_length(bytes, position + 1).then do |length, data_start|
            if type == META_SET_TEMPO
              events << {
                type:  :set_tempo,
                ticks: ticks,
                tempo: bytes.byteslice(data_start, 3).bytes.inject(0) { |acc, byte| (acc << 8) | byte },
              }
            end
            data_start + length
          end
        end
      end

      def skip_sysex(bytes, position)
        read_variable_length(bytes, position).then { |length, data_start| data_start + length }
      end

      def read_voice_event(bytes, position, status, ticks, events)
        VOICE_MESSAGE_LENGTHS.fetch(status.to_i & 0xF0, 2).then do |data_length|
          if (status & 0xF0) == STATUS_NOTE_ON && bytes.getbyte(position + 1).to_i.positive?
            events << { type: :note_on, ticks: ticks, note: bytes.getbyte(position) }
          end
          position + data_length
        end
      end

      # Returns [value, position_after].
      def read_variable_length(bytes, position)
        value = 0
        cursor = position
        more = true
        while more
          bytes.getbyte(cursor).then do |byte|
            value = (value << 7) | (byte.to_i & 0x7F)
            cursor += 1
            more = !byte.nil? && byte >= 0x80
          end
        end
        [value, cursor]
      end
  end
end
