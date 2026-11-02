# frozen_string_literal: true

require "gtk4"
require_relative "audio_export_dialog"
require_relative "constants"

module DrumMachine
  # FileDialogs — ported from upstream's
  # src/handlers/file_dialog_handler.py (its setup_pattern_menu lives in
  # PatternMenu instead).
  #
  # Six Gtk::FileDialog flows: open a pattern, save a pattern, add samples,
  # replace one sample, save an exported audio file and pick cover art. Each
  # has its own title and filter.
  #
  # #filename is the basename of the last pattern opened or saved, which the
  # export dialog reuses as its suggested name.
  class FileDialogs
    MIDI_FILTER_NAME = "MIDI files"
    AUDIO_FILTER_NAME = "Audio files"
    IMAGE_FILTER_NAME = "Image files"
    IMAGE_PATTERNS = ["*.png", "*.jpg", "*.jpeg"].freeze
    DEFAULT_SAVE_NAME = "new_sequence"
    MIDI_EXTENSION = ".mid"

    attr_accessor :filename

    def initialize(window)
      @window = window
      @filename = nil
    end

    # --- patterns --------------------------------------------------------

    # Opening throws the current pattern away, so an unsaved one is offered to
    # be saved first.
    def handle_open_file
      if @window.save_changes_service.unsaved_changes?
        @window.save_changes_service.prompt_save_changes(
          on_save:    -> { show_save_dialog(method(:open_file_directly)) },
          on_discard: method(:open_file_directly),
        )
      else
        open_file_directly
      end
    end

    def handle_save_pattern = show_save_dialog

    def handle_export_audio
      AudioExportDialog.new(
        window:               @window,
        audio_export_service: @window.audio_export_service,
        drum_parts_state:     @window.drum_machine_service.drum_parts_state,
        bpm:                  @window.drum_machine_service.bpm,
        suggested_filename:   @filename,
      ).tap do |dialog|
        dialog.build
        dialog.present(@window.window)
      end
    end

    # The win.load-pattern action's target: one of the bundled patterns, by
    # name, resolved against data/patterns.
    def load_named_pattern(pattern_name)
      if @window.save_changes_service.unsaved_changes?
        @window.save_changes_service.prompt_save_changes(
          on_save:    -> { show_save_dialog(-> { open_pattern_directly(pattern_name) }) },
          on_discard: -> { open_pattern_directly(pattern_name) },
        )
      else
        open_pattern_directly(pattern_name)
      end
    end

    def show_save_dialog(after_save = nil)
      save_pattern_dialog.save(@window.window) do |dialog, result|
        begin
          dialog.save_finish(result).then do |file|
            if file
              save_pattern_to(file, after_save)
            end
          end
        rescue GLib::Error => e
          warn "drum-machine: save dialog cancelled or failed: #{e.message}"
        end
      end
    end

    # --- samples ---------------------------------------------------------

    def handle_add_samples
      open_audio_file_chooser("Add Audio Samples", multiple: true) do |files|
        @window.drag_drop.handle_multiple_files_drop(files, nil)
      end
    end

    # One chooser for both the "Add Samples…" and "Replace…" flows; `multiple`
    # is what tells them apart. The block is handed a path, or an array of
    # paths when multiple is true.
    def open_audio_file_chooser(title, multiple: false, &block)
      audio_dialog(title).then do |dialog|
        if multiple
          dialog.open_multiple(@window.window) { |dlg, result| finish_open_multiple(dlg, result, &block) }
        else
          dialog.open(@window.window) { |dlg, result| finish_open(dlg, result, &block) }
        end
      end
    end

    def open_cover_art_chooser(&block)
      cover_art_dialog.open(@window.window) { |dlg, result| finish_open(dlg, result, &block) }
    end

    # --- dialogs ---------------------------------------------------------

    def open_pattern_dialog
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = "Open MIDI File"
        dialog.filters = filter_store(midi_filter)
        dialog.modal = true
      end
    end

    def save_pattern_dialog
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = "Save Sequence"
        dialog.filters = filter_store(midi_filter)
        dialog.modal = true
        dialog.initial_name = "#{@filename || DEFAULT_SAVE_NAME}#{MIDI_EXTENSION}"
      end
    end

    def audio_dialog(title)
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = title
        dialog.filters = filter_store(audio_filter)
        dialog.modal = true
      end
    end

    def cover_art_dialog
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = "Select Cover Art"
        dialog.filters = filter_store(image_filter)
      end
    end

    # The export dialog's save chooser, named and filtered for whichever audio
    # format is selected.
    def save_audio_dialog(format_info, initial_name)
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = "Save Audio File"
        dialog.filters = filter_store(pattern_filter(format_info.name, [format_info.pattern]))
        dialog.initial_name = initial_name
      end
    end

    private

      def filter_store(filter)
        Gio::ListStore.new(Gtk::FileFilter).tap { |store| store.append(filter) }
      end

      def pattern_filter(name, patterns)
        Gtk::FileFilter.new.tap do |filter|
          filter.name = name
          patterns.each { |pattern| filter.add_pattern(pattern) }
        end
      end

      def midi_filter = pattern_filter(MIDI_FILTER_NAME, ["*#{MIDI_EXTENSION}"])

      def audio_filter
        pattern_filter(
          AUDIO_FILTER_NAME,
          Constants::SUPPORTED_INPUT_AUDIO_FORMATS.map { |ext| "*#{ext}" },
        )
      end

      def image_filter = pattern_filter(IMAGE_FILTER_NAME, IMAGE_PATTERNS)

      def finish_open(dialog, result)
        dialog.open_finish(result).then do |file|
          if file
            yield(file.path)
          end
        end
      rescue GLib::Error => e
        warn "drum-machine: file dialog cancelled or failed: #{e.message}"
      end

      def finish_open_multiple(dialog, result)
        dialog.open_multiple_finish(result).then do |files|
          if files && files.n_items.positive?
            yield(Array.new(files.n_items) { |index| files.get_item(index).path }.compact)
          end
        end
      rescue GLib::Error => e
        warn "drum-machine: file dialog cancelled or failed: #{e.message}"
      end

      def open_file_directly
        open_pattern_dialog.open(@window.window) do |dialog, result|
          begin
            dialog.open_finish(result).then do |file|
              if file
                load_pattern_from(file)
              end
            end
          rescue GLib::Error => e
            warn "drum-machine: file dialog cancelled or failed: #{e.message}"
          rescue StandardError => e
            warn "drum-machine: failed to open pattern file: #{e.message}"
            @window.show_toast("Failed to open file")
          end
        end
      end

      def load_pattern_from(file)
        @window.drum_machine_service.load_pattern(file.path)
        refresh_after_load
        @filename = File.basename(file.path, ".*")
      end

      def open_pattern_directly(pattern_name)
        File.join(Constants.patterns_dir, "#{pattern_name}#{MIDI_EXTENSION}").then do |file_path|
          begin
            @window.drum_machine_service.load_pattern(file_path)
            refresh_after_load
            @filename = nil
          rescue StandardError => e
            warn "drum-machine: failed to load default pattern '#{pattern_name}': #{e.message}"
            @window.show_toast("Failed to load pattern")
          end
        end
      end

      def refresh_after_load
        @window.drum_machine_service.update_total_beats
        @window.drum_grid.reset_carousel_pages
        @window.ui_helper.load_pattern_into_ui(@window.drum_machine_service.drum_parts_state)
        @window.update_export_button_sensitivity
        @window.save_changes_service.mark_unsaved_changes(false)
      end

      def save_pattern_to(file, after_save)
        with_midi_extension(file.path).then do |file_path|
          @window.drum_machine_service.save_pattern(file_path)
          @window.save_changes_service.mark_unsaved_changes(false)
          @filename = File.basename(file_path, ".*")
          after_save&.call
        end
      end

      def with_midi_extension(file_path)
        if file_path.end_with?(MIDI_EXTENSION)
          file_path
        else
          "#{file_path}#{MIDI_EXTENSION}"
        end
      end
  end
end
