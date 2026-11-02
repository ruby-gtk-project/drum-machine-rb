# frozen_string_literal: true

require "gtk4"
require_relative "reset_defaults_dialog"

module DrumMachine
  # WindowActions — ported from upstream's src/handlers/window_actions.py.
  #
  # Eighteen window actions and their accelerators, installed in a loop, plus
  # the two parameterised ones upstream installs elsewhere: win.load-pattern
  # (from the pattern menu) and win.open-file (from the toast that offers to
  # open an exported file).
  #
  # Note win.load_pattern and win.load-pattern are two different actions and
  # both exist upstream — the underscore one opens the file chooser, the hyphen
  # one takes a bundled pattern's name as a string. Both are reproduced.
  class WindowActions
    # [action name, handler, accelerators]
    ACTIONS = [
      ["open_menu", :on_open_menu, ["F10"]],
      ["play_pause", :on_play_pause, ["space"]],
      ["clear_toggles", :on_clear, ["<primary>Delete"]],
      ["increase_bpm", :on_increase_bpm, ["plus", "equal"]],
      ["decrease_bpm", :on_decrease_bpm, ["minus"]],
      ["increase_volume", :on_increase_volume, ["<primary>Up"]],
      ["decrease_volume", :on_decrease_volume, ["<primary>Down"]],
      ["load_pattern", :on_open_file, ["<primary>o"]],
      ["save_pattern", :on_save_pattern, ["<primary>s"]],
      ["export_audio", :on_export_audio, ["<primary>e"]],
      ["add_samples", :on_add_samples, ["<primary><shift>a"]],
      ["reset_to_defaults", :on_reset_to_defaults, []],
      ["quit", :on_quit, ["<primary>q"]],
      ["close_window", :on_quit, ["<primary>w"]],
      ["go_to_instrument", :on_go_to_instrument, ["<primary>i"]],
      ["previous_page", :on_previous_page, ["Page_Up"]],
      ["next_page", :on_next_page, ["Page_Down"]],
      ["mute", :on_mute, ["<primary>m"]],
    ].freeze

    BPM_STEP = 1
    VOLUME_STEP = 5
    MAX_VOLUME = 100
    MIN_VOLUME = 0
    TOGGLE_NAME_SEPARATOR = "_toggle_"

    def initialize(window)
      @window = window
    end

    def setup_actions
      ACTIONS.each { |name, handler, accelerators| create_action(name, handler, accelerators) }
      create_parameterised_action("load-pattern", :on_load_named_pattern)
      create_parameterised_action("open-file", :on_open_exported_file)
    end

    # --- handlers --------------------------------------------------------

    def on_open_menu = @window.menu_button.activate

    def on_play_pause = @window.handle_play_pause

    def on_clear = @window.handle_clear

    def on_increase_bpm
      @window.bpm_spin_button.value = @window.bpm_spin_button.value + BPM_STEP
    end

    def on_decrease_bpm
      @window.bpm_spin_button.value = @window.bpm_spin_button.value - BPM_STEP
    end

    def on_increase_volume
      @window.volume_button.value = [@window.volume_button.value + VOLUME_STEP, MAX_VOLUME].min
    end

    def on_decrease_volume
      @window.volume_button.value = [@window.volume_button.value - VOLUME_STEP, MIN_VOLUME].max
    end

    def on_open_file = @window.file_dialogs.handle_open_file

    def on_save_pattern = @window.file_dialogs.handle_save_pattern

    def on_export_audio = @window.file_dialogs.handle_export_audio

    def on_add_samples = @window.file_dialogs.handle_add_samples

    def on_reset_to_defaults
      ResetDefaultsDialog.new(
        window:   @window,
        on_reset: @window.method(:reset_to_defaults),
      ).tap do |dialog|
        dialog.build
        dialog.present(@window.window)
      end
    end

    # Both the quit action and the window's close-request land here.
    def on_quit
      if @window.save_changes_service.unsaved_changes?
        @window.save_changes_service.prompt_save_changes(
          on_save:    @window.method(:save_and_close),
          on_discard: @window.method(:cleanup_and_destroy),
        )
      else
        @window.cleanup_and_destroy
      end
    end

    # Jumps from whichever beat toggle has the focus to that row's instrument
    # button. The part id comes out of the focused widget's name, which is why
    # the grid still names every toggle "<part_id>_toggle_<n>".
    def on_go_to_instrument
      @window.focus.then do |focused|
        focused&.name.to_s.then do |widget_name|
          if widget_name.include?(TOGGLE_NAME_SEPARATOR)
            @window.drum_grid.instrument_button(widget_name.split(TOGGLE_NAME_SEPARATOR).first)&.grab_focus
          end
        end
      end
    end

    def on_previous_page
      @window.drum_grid.carousel.then do |carousel|
        if carousel && carousel.position.to_i.positive?
          carousel.scroll_to(carousel.get_nth_page(carousel.position.to_i - 1), true)
        end
      end
    end

    def on_next_page
      @window.drum_grid.carousel.then do |carousel|
        if carousel && carousel.position.to_i < carousel.n_pages - 1
          carousel.scroll_to(carousel.get_nth_page(carousel.position.to_i + 1), true)
        end
      end
    end

    # Mute is a toggle: zero goes back to the volume before the mute.
    def on_mute
      if @window.volume_button.value.zero?
        @window.volume_button.value = @window.drum_machine_service.last_volume
      else
        @window.volume_button.value = MIN_VOLUME
      end
    end

    def on_load_named_pattern(parameter)
      @window.file_dialogs.load_named_pattern(parameter.get_string)
    end

    # The "Open" button on the export-finished toast.
    def on_open_exported_file(parameter)
      Gio::AppInfo.launch_default_for_uri("file://#{parameter.get_string}", nil)
    end

    private

      def create_action(name, handler, accelerators)
        Gio::SimpleAction.new(name, nil).tap do |action|
          action.signal_connect("activate") { public_send(handler) }
          @window.add_action(action)
          unless accelerators.empty?
            @window.application.set_accels_for_action("win.#{name}", accelerators)
          end
        end
      end

      def create_parameterised_action(name, handler)
        Gio::SimpleAction.new(name, GLib::VariantType.new("s")).tap do |action|
          action.signal_connect("activate") { |_action, parameter| public_send(handler, parameter) }
          @window.add_action(action)
        end
      end
  end
end
