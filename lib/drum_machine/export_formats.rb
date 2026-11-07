# frozen_string_literal: true

require_relative "translation"

module DrumMachine
  # ExportFormat / ExportFormatRegistry — ported from upstream's
  # src/config/export_formats.py.
  #
  # The integer keys are the row indices of the export dialog's format combo,
  # so the order below is the order the dialog lists.
  ExportFormat = Data.define(
    :ext,
    :pattern,
    :name,
    :display,
    :supports_metadata,
  ) do
    def supports_metadata? = supports_metadata
  end

  # Registry for managing available export formats.
  class ExportFormatRegistry
    extend Translatable

    FORMATS = {
      0 => ExportFormat.new(
        ext:               ".mp3",
        pattern:           "*.mp3",
        name:              _("MP3 files"),
        display:           _("MP3"),
        supports_metadata: true,
      ),
      1 => ExportFormat.new(
        ext:               ".flac",
        pattern:           "*.flac",
        name:              _("FLAC files"),
        display:           _("FLAC (Lossless)"),
        supports_metadata: true,
      ),
      2 => ExportFormat.new(
        ext:               ".ogg",
        pattern:           "*.ogg",
        name:              _("Ogg files"),
        display:           _("Ogg Vorbis"),
        supports_metadata: true,
      ),
      3 => ExportFormat.new(
        ext:               ".wav",
        pattern:           "*.wav",
        name:              _("WAV files"),
        display:           _("WAV (Uncompressed)"),
        supports_metadata: false,
      ),
    }.freeze

    # Format configuration by combo-row index; an out-of-range index falls back
    # to MP3, exactly as upstream's dict.get(format_id, formats[0]) does.
    def get_format(format_id) = FORMATS.fetch(format_id.to_i, FORMATS[0])

    def all_formats = FORMATS.dup

    def get_format_by_extension(extension)
      FORMATS.each_value.find { |fmt| fmt.ext == extension.to_s.downcase } || FORMATS[0]
    end
  end
end
