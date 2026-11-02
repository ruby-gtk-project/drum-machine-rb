# frozen_string_literal: true

require "securerandom"
require_relative "name_utils"

module DrumMachine
  # DrumPart — ported from upstream's src/models/drum_part.py.
  #
  # A mutable record: replace_part and update_part_midi_note both write to a
  # part in place, so this stays a plain class with accessors rather than a
  # frozen Data.
  class DrumPart
    attr_accessor :id, :name, :file_path, :is_custom, :midi_note_id

    def initialize(id:, name:, file_path:, is_custom: false, midi_note_id: nil)
      @id = id
      @name = name
      @file_path = file_path
      @is_custom = is_custom
      @midi_note_id = midi_note_id
    end

    # A bundled sample: the id is derived from the filename so it survives a
    # reset to defaults, and the display name is the filename titleized.
    def self.create_default(name, file_path, midi_note_id)
      new(
        id:           "default_#{name}",
        name:         NameUtils.titleize(name.to_s.tr("-", " ")),
        file_path:    file_path,
        is_custom:    false,
        midi_note_id: midi_note_id,
      )
    end

    # A user-supplied sample: the id is a fresh UUID, the name comes from the
    # caller (which has already run it through NameUtils).
    def self.create_custom(name, file_path, midi_note_id)
      new(
        id:           SecureRandom.uuid,
        name:         name,
        file_path:    file_path,
        is_custom:    true,
        midi_note_id: midi_note_id,
      )
    end

    def custom? = @is_custom == true

    # A part loaded from a pattern whose MIDI note matches no sample has no
    # file behind it: it shows in the grid and exports silent.
    def temporary? = @file_path.to_s.empty?

    def file_available? = !temporary? && File.exist?(@file_path)

    def to_h
      {
        id:           @id,
        name:         @name,
        file_path:    @file_path,
        is_custom:    @is_custom,
        midi_note_id: @midi_note_id,
      }
    end

    def self.from_h(data)
      new(
        id:           data[:id] || data["id"],
        name:         data[:name] || data["name"],
        file_path:    data[:file_path] || data["file_path"],
        is_custom:    data[:is_custom] || data["is_custom"] || false,
        midi_note_id: data[:midi_note_id] || data["midi_note_id"],
      )
    end

    def to_s = "#<DrumMachine::DrumPart id=#{@id.inspect} name=#{@name.inspect}>"
    def inspect = to_s
  end
end
