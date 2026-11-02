# frozen_string_literal: true

require "securerandom"
require_relative "constants"
require_relative "drum_part"

module DrumMachine
  # DrumPartManager — ported from upstream's src/services/drum_part_manager.py.
  #
  # Owns the ordered list of drum parts: the bundled ten, whatever the user has
  # added or dropped, and the temporary parts a loaded MIDI pattern invents for
  # notes no sample claims.
  class DrumPartManager
    # Default MIDI note mapping for the bundled drum parts.
    DEFAULT_MIDI_NOTES = {
      "kick"    => 36,
      "kick-2"  => 35,
      "kick-3"  => 34,
      "snare"   => 38,
      "snare-2" => 37,
      "hihat"   => 42,
      "hihat-2" => 44,
      "clap"    => 39,
      "tom"     => 41,
      "crash"   => 49,
    }.freeze

    # Custom parts are numbered from the start of the General MIDI percussion
    # range so they land somewhere a drum machine will understand.
    GM_PERCUSSION_FIRST_NOTE = 35
    MIDI_NOTE_COUNT = 128

    MAX_FILE_SIZE_MB = 50

    def initialize(bundled_sounds_dir)
      @bundled_sounds_dir = bundled_sounds_dir
      @drum_parts = []
      load_default_parts
    end

    def all_parts = @drum_parts.dup

    def get_part_by_id(part_id) = @drum_parts.find { |part| part.id == part_id }

    def parts_by_id = @drum_parts.to_h { |part| [part.id, part] }

    def get_part_by_midi_note(midi_note) = @drum_parts.find { |part| part.midi_note_id == midi_note }

    # The part a MIDI note maps to, inventing a silent placeholder part when
    # the pattern names a note none of the loaded samples answers to.
    def get_or_create_part_for_midi_note(midi_note)
      get_part_by_midi_note(midi_note).then do |part|
        if part
          part
        else
          DrumPart.new(
            id:           SecureRandom.uuid,
            name:         "Note #{midi_note}",
            file_path:    "",
            is_custom:    true,
            midi_note_id: midi_note,
          ).tap { |temp_part| @drum_parts << temp_part }
        end
      end
    end

    def add_temporary_part(drum_part)
      @drum_parts << drum_part
      drum_part
    end

    # Adds a user-supplied sample. Returns the new part, or nil when the name
    # or the file will not do.
    def add_custom_part(name, source_file)
      if name.to_s.empty? || source_file.to_s.empty?
        warn "drum-machine: invalid drum part: name=#{name.inspect} source=#{source_file.inspect}"
        nil
      elsif !File.exist?(source_file)
        warn "drum-machine: source file does not exist: #{source_file}"
        nil
      else
        DrumPart.create_custom(name, source_file, next_available_midi_note).tap do |part|
          @drum_parts << part
        end
      end
    end

    def remove_part(part_id)
      get_part_by_id(part_id).then do |part|
        if part
          @drum_parts = @drum_parts.reject { |candidate| candidate.id == part_id }
          true
        else
          false
        end
      end
    end

    # Moves a part to a new position in the column. The index is the position
    # in the list after the part has been taken out, which is what the column's
    # drop handler computes.
    def reorder_part(part_id, new_index)
      get_part_by_id(part_id).then do |part|
        if part.nil?
          false
        elsif new_index.negative? || new_index >= @drum_parts.length
          warn "drum-machine: invalid reorder index: #{new_index}"
          false
        elsif @drum_parts.index(part) == new_index
          true
        else
          @drum_parts.delete(part)
          @drum_parts.insert(new_index, part)
          true
        end
      end
    end

    def get_part_index(part_id) = @drum_parts.index { |part| part.id == part_id } || -1

    # Points an existing part at a different file. The part keeps its id, so
    # the pattern written against it survives the swap.
    def replace_part(part_id, source_file, new_name)
      if part_id.to_s.empty? || source_file.to_s.empty?
        warn "drum-machine: invalid replacement: part_id=#{part_id.inspect} source=#{source_file.inspect}"
        nil
      else
        get_part_by_id(part_id).then do |part|
          if part
            part.tap do |target|
              target.name = new_name
              target.file_path = source_file
              target.is_custom = true
            end
          else
            warn "drum-machine: drum part not found: #{part_id}"
            nil
          end
        end
      end
    end

    def update_part_midi_note(part_id, midi_note)
      get_part_by_id(part_id).then do |part|
        if part
          part.midi_note_id = midi_note
          true
        else
          false
        end
      end
    end

    def file_available?(part_id)
      get_part_by_id(part_id).then { |part| part ? part.file_available? : false }
    end

    def reset_to_defaults
      @drum_parts = []
      load_default_parts
    end

    private

      def load_default_parts
        Constants::DEFAULT_DRUM_PARTS.each do |name|
          File.join(@bundled_sounds_dir, "#{name}.wav").then do |file_path|
            if File.exist?(file_path)
              @drum_parts << DrumPart.create_default(name, file_path, DEFAULT_MIDI_NOTES[name])
            end
          end
        end
      end

      def used_notes = @drum_parts.filter_map(&:midi_note_id).uniq

      # The first free note at or after the start of the GM percussion range,
      # wrapping down into 0..34 once 35..127 is full.
      def next_available_midi_note
        used_notes.then do |taken|
          (GM_PERCUSSION_FIRST_NOTE...MIDI_NOTE_COUNT).find { |note| !taken.include?(note) } ||
            (0...GM_PERCUSSION_FIRST_NOTE).find { |note| !taken.include?(note) }
        end
      end
  end
end
