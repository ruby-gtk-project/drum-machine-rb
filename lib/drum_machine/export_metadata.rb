# frozen_string_literal: true

require "etc"
require_relative "translation"

module DrumMachine
  # ExportMetadata — ported from the second class in upstream's
  # src/dialogs/audio_export_dialog.py.
  #
  # Owns the export dialog's three metadata rows: artist, song name and cover
  # art. The artist row is prefilled with the system user name, which is what
  # getpass.getuser() gives upstream.
  class ExportMetadata
    extend Translatable

    COVER_LABEL_LIMIT = 20
    CHOOSE_FILE_LABEL = _("Choose File…")

    attr_reader :cover_art_path

    def initialize(artist_row, song_row, cover_row, cover_button)
      @artist_row = artist_row
      @song_row = song_row
      @cover_row = cover_row
      @cover_button = cover_button
      @cover_art_path = nil
      setup_defaults
    end

    def metadata
      {
        artist:    presence(@artist_row.text),
        title:     title,
        cover_art: @cover_art_path,
      }
    end

    def title = presence(@song_row.text)

    # Remembers the chosen file and relabels the button with its basename,
    # truncated so a long filename cannot stretch the dialog.
    def set_cover_art(file_path)
      @cover_art_path = file_path
      file_path.then do |path|
        if path
          @cover_button.label = truncate(File.basename(path))
        end
      end
    end

    def sensitive=(sensitive)
      @artist_row.sensitive = sensitive
      @song_row.sensitive = sensitive
      @cover_row.sensitive = sensitive
      @cover_button.sensitive = sensitive
    end

    private

      def setup_defaults
        @artist_row.text = Etc.getlogin || Etc.getpwuid(Process.uid).name
      rescue ArgumentError, TypeError => e
        warn "drum-machine: failed to get system username for metadata: #{e.message}"
      end

      def presence(text) = text.to_s.strip.then { |value| value.empty? ? nil : value }

      def truncate(name)
        if name.length > COVER_LABEL_LIMIT
          "#{name[0, COVER_LABEL_LIMIT]}…"
        else
          name
        end
      end
  end
end
