# frozen_string_literal: true

require "adwaita"
require_relative "audio_export_service"
require_relative "constants"
require_relative "drag_drop"
require_relative "drum_grid"
require_relative "drum_machine_service"
require_relative "file_dialogs"
require_relative "pattern_menu"
require_relative "primary_menu"
require_relative "save_changes_service"
require_relative "sound_service"
require_relative "translation"
require_relative "ui_helper"
require_relative "window_actions"

module DrumMachine
  # Window — ported from upstream's src/window.py and src/window.ui.
  #
  # One Adwaita::ApplicationWindow: a header bar with the pattern split button,
  # the export button and the main menu; the drum grid in a scrolled window;
  # and a bottom bar with the BPM spin button, the play/pause button, the
  # volume scale button and Clear.
  #
  # Upstream's window is a Gtk.Template subclass. Adwaita::ApplicationWindow
  # cannot be subclassed through these bindings, so this is a plain class that
  # owns the window and forwards the handful of widget calls the handlers make
  # — which is also what the house style asks for: memoized widgets, all
  # configuration in their taps, assembly only in #build.
  class Window
    include Translatable

    DEFAULT_WIDTH = 1000
    DEFAULT_HEIGHT = 800
    MIN_WIDTH = 360
    MIN_HEIGHT = 420
    PLAY_BUTTON_SIZE = 60
    TOAST_TIMEOUT = 5

    # Each breakpoint's condition and the css-classes it writes onto
    # drum_machine_box. The box's notify::css-classes signal is the whole
    # responsive mechanism: nothing else tells the app it got narrow.
    BASE_BOX_CLASSES = ["drum-machine-box"].freeze

    BREAKPOINTS = [
      ["max-width: 890px or max-height: 625px", ["drum-machine-box", "medium"], false],
      ["max-width: 740px or max-height: 560px", ["drum-machine-box", "compact"], false],
      ["max-width: 500px", ["drum-machine-box", "compact", "half-view"], false],
      ["max-width: 395px", ["drum-machine-box", "compact", "half-view"], true],
    ].freeze

    VOLUME_ICONS = [
      "audio-volume-muted-symbolic",
      "audio-volume-high-symbolic",
      "audio-volume-low-symbolic",
      "audio-volume-medium-symbolic",
    ].freeze

    def initialize(application)
      @application = application
    end

    attr_reader :application

    # --- assembly --------------------------------------------------------

    def build
      window.tap do |win|
        win.content = toast_overlay

        BREAKPOINTS.each { |condition, classes, hide_bpm| win.add_breakpoint(breakpoint(condition, classes, hide_bpm)) }

        toast_overlay.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = outer_box
          view.add_bottom_bar(bottom_wrapper)
        end

        build_header_bar
        build_outer_box
        build_bottom_wrapper

        drum_machine_box.append(drum_grid.build)

        connect_signals
        window_actions.setup_actions
        drag_drop.setup_drag_drop
        update_export_button_sensitivity
      end
    end

    def present = window.present

    def destroy = window.destroy

    # --- widgets ---------------------------------------------------------

    def window
      @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
        win.add_css_class("adw-window")
        win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        win.width_request = MIN_WIDTH
        win.height_request = MIN_HEIGHT
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    # Positional, not keyword, arguments — the title and subtitle are required
    # even though the error a no-argument new raises advertises them as names.
    def window_title = @window_title ||= Adwaita::WindowTitle.new(_("Drum Machine"), "")

    def file_pattern_button
      @file_pattern_button ||= Adwaita::SplitButton.new.tap do |button|
        button.label = _("Open…")
        button.use_underline = true
        button.tooltip_text = _("Open Pattern")
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = _("Main Menu")
      end
    end

    def export_audio_button
      @export_audio_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "share-symbolic"
        button.tooltip_text = _("Export Audio…")
        button.add_css_class("export-button")
      end
    end

    def outer_box = @outer_box ||= Gtk::Box.new(:vertical, 0)

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.vexpand = true
        scrolled.hexpand = true
      end
    end

    def drum_machine_box
      @drum_machine_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.halign = :center
        box.valign = :center
        box.margin_start = 12
        box.margin_end = 12
        box.margin_top = 12
        box.margin_bottom = 12
        box.add_css_class("drum-machine-box")
      end
    end

    def bottom_wrapper
      @bottom_wrapper ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class("bottom-wrapper")
        box.hexpand = true
      end
    end

    def bpm_box
      @bpm_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.halign = :start
        box.valign = :center
        box.margin_start = 12
      end
    end

    def bpm_label
      @bpm_label ||= Gtk::Label.new(_("BPM")).tap { |label| label.valign = :center }
    end

    def bpm_adjustment
      @bpm_adjustment ||= Gtk::Adjustment.new(
        Constants::DEFAULT_BPM,
        30,
        300,
        1,
        10,
        0,
      )
    end

    def bpm_spin_button
      @bpm_spin_button ||= Gtk::SpinButton.new(bpm_adjustment, 1, 0).tap do |button|
        button.tooltip_text = _("Adjust Tempo In Beats per Minute (BPM)")
        button.valign = :center
      end
    end

    def centre_box
      @centre_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.hexpand = true
        box.halign = :center
        box.valign = :center
      end
    end

    def play_pause_button
      @play_pause_button ||= Gtk::Button.new.tap do |button|
        button.width_request = PLAY_BUTTON_SIZE
        button.height_request = PLAY_BUTTON_SIZE
        button.icon_name = "media-playback-start-symbolic"
        button.tooltip_text = _("Play")
        button.valign = :center
        button.add_css_class("circular")
      end
    end

    def volume_adjustment
      @volume_adjustment ||= Gtk::Adjustment.new(
        Constants::DEFAULT_VOLUME,
        0,
        100,
        1,
        5,
        0,
      )
    end

    def volume_button
      @volume_button ||= Gtk::ScaleButton.new.tap do |button|
        button.valign = :center
        button.icons = VOLUME_ICONS
        button.tooltip_text = _("Adjust Volume")
        button.adjustment = volume_adjustment
      end
    end

    def clear_box
      @clear_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :end
        box.valign = :center
        box.margin_end = 12
      end
    end

    def clear_button
      @clear_button ||= Gtk::Button.new(label: _("Clear")).tap do |button|
        button.valign = :center
        button.tooltip_text = _("Clear the Drum Pattern")
      end
    end

    # --- services and handlers -------------------------------------------

    def sound_service
      @sound_service ||= SoundService.new(Constants.drumkit_dir).tap(&:load_sounds)
    end

    def audio_export_service = @audio_export_service ||= AudioExportService.new(self)
    def ui_helper = @ui_helper ||= UIHelper.new(self)

    def drum_machine_service
      @drum_machine_service ||= DrumMachineService.new(self, sound_service, ui_helper)
    end

    def save_changes_service
      @save_changes_service ||= SaveChangesService.new(self, drum_machine_service)
    end

    def drum_grid = @drum_grid ||= DrumGrid.new(self)
    def window_actions = @window_actions ||= WindowActions.new(self)
    def file_dialogs = @file_dialogs ||= FileDialogs.new(self)
    def drag_drop = @drag_drop ||= DragDrop.new(self)
    def primary_menu = @primary_menu ||= PrimaryMenu.new
    def pattern_menu = @pattern_menu ||= PatternMenu.new

    # --- window-level behaviour -------------------------------------------

    # Export and Clear are both meaningless with an empty pattern, so both go
    # insensitive until a beat is on somewhere.
    def update_export_button_sensitivity
      drum_machine_service.drum_parts_state.each_value.any? do |beats|
        beats.each_value.any? { |active| active }
      end.then do |has_active_beats|
        export_audio_button.sensitive = has_active_beats
        clear_button.sensitive = has_active_beats
      end
    end

    def scroll_carousel_to_page(page_index)
      drum_grid.carousel.then do |carousel|
        if carousel && carousel.position.to_i != page_index && page_index < carousel.n_pages
          carousel.scroll_to(carousel.get_nth_page(page_index), true)
        end
      end
    end

    def on_toggle_changed(toggle_button, part, index)
      if toggle_button.active?
        drum_machine_service.drum_parts_state[part][index] = true
      else
        drum_machine_service.drum_parts_state[part]&.delete(index)
      end

      drum_machine_service.update_total_beats
      update_export_button_sensitivity
      save_changes_service.mark_unsaved_changes(true)
    end

    def on_bpm_changed
      bpm_spin_button.value.then do |value|
        drum_machine_service.set_bpm(value)
        bpm_spin_button.tooltip_text = pyfmt(_("{} Beats per Minute (BPM)"), value.to_i)
        save_changes_service.mark_unsaved_changes(true)
      end
    end

    def on_volume_changed(value)
      drum_machine_service.set_volume(value)
      volume_button.tooltip_text = pyfmt(_("{:.0f}% Volume"), value)
    end

    def handle_clear
      drum_machine_service.clear_all_toggles
      drum_machine_service.update_total_beats
      drum_grid.reset_carousel_pages
      update_export_button_sensitivity
      save_changes_service.mark_unsaved_changes(false)
    end

    # Clears the pattern and puts the samples, tempo and volume back where
    # they started.
    def reset_to_defaults
      drum_machine_service.clear_all_toggles
      sound_service.drum_part_manager.reset_to_defaults
      sound_service.reload_sounds
      drum_machine_service.drum_parts_state = drum_machine_service.create_empty_drum_parts_state
      drum_machine_service.set_bpm(Constants::DEFAULT_BPM)
      drum_machine_service.set_volume(Constants::DEFAULT_VOLUME)
      drum_grid.rebuild_drum_parts_column
      drum_grid.rebuild_carousel
      drum_machine_service.update_total_beats
      drum_grid.reset_carousel_pages
      bpm_spin_button.value = Constants::DEFAULT_BPM
      volume_button.value = Constants::DEFAULT_VOLUME
      update_export_button_sensitivity
      save_changes_service.mark_unsaved_changes(false)
    end

    def handle_play_pause
      if drum_machine_service.playing?
        play_pause_button.icon_name = "media-playback-start-symbolic"
        play_pause_button.tooltip_text = _("Play")
        drum_machine_service.stop
      else
        play_pause_button.icon_name = "media-playback-pause-symbolic"
        play_pause_button.tooltip_text = _("Pause")
        drum_machine_service.play
      end
    end

    def on_drum_part_button_clicked(part_id)
      drum_machine_service.preview_drum_part(part_id)
    end

    # Right-clicking a beat toggle flips it; the toggled signal is emitted by
    # hand because setting active from code already does that.
    def on_right_click_released(toggle_button)
      toggle_button.active = !toggle_button.active?
    end

    # --- responsive layout ------------------------------------------------

    def on_breakpoint_changed
      drum_machine_box.css_classes.then do |classes|
        handle_layout_change(classes.include?("half-view"))
        drum_grid.update_drum_parts_spacing(is_compact: classes.include?("compact"))
      end
    end

    # Below 500px the grid shows half as many beats per page, which means a
    # full carousel rebuild focused on wherever the user (or the playhead)
    # already was.
    def handle_layout_change(is_tiny)
      beats_per_page_for(is_tiny).then do |beats_per_page|
        unless drum_machine_service.beats_per_page == beats_per_page
          focus_beat_index(drum_machine_service.beats_per_page).then do |focus_beat|
            drum_machine_service.beats_per_page = beats_per_page
            drum_machine_service.update_total_beats
            drum_grid.rebuild_carousel(focus_beat_index: focus_beat)
          end
        end
      end
    end

    # --- toasts ----------------------------------------------------------

    def show_toast(message, open_file: false, file_path: nil)
      Adwaita::Toast.new(message).tap do |toast|
        toast.timeout = TOAST_TIMEOUT

        if open_file && file_path
          toast.action_name = "win.open-file"
          toast.set_action_target_value(GLib::Variant.new(file_path))
          toast.button_label = _("Open")
        end

        toast_overlay.add_toast(toast)
      end
    end

    def show_added_toast(name) = show_toast(pyfmt(_("Added: {}"), name))

    def add_new_drum_part(file_path, name, show_success_toast: true)
      drum_machine_service.add_new_drum_part(file_path, name).then do |result|
        if result
          if show_success_toast
            show_added_toast(name)
          end
          save_changes_service.mark_unsaved_changes(true)
        else
          show_toast(_("Failed to add custom sound"))
        end
        !result.nil?
      end
    end

    def replace_drum_part(drum_id, file_path, name)
      drum_machine_service.replace_drum_part(drum_id, file_path, name).then do |result|
        if result
          show_toast(pyfmt(_("Replaced drum with: {}"), name))
          drum_grid.update_drum_button(drum_id)
          save_changes_service.mark_unsaved_changes(true)
        else
          show_toast(_("Failed to replace drum sound"))
        end
        !result.nil?
      end
    end

    # --- shutdown --------------------------------------------------------

    def save_and_close = file_dialogs.show_save_dialog(method(:cleanup_and_destroy))

    def cleanup
      if drum_machine_service.playing?
        drum_machine_service.stop
      end
      drum_machine_service.playing = false
    end

    def cleanup_and_destroy
      cleanup
      destroy
    end

    # --- delegation the handlers rely on ----------------------------------

    def add_action(action) = window.add_action(action)
    def add_controller(controller) = window.add_controller(controller)
    def add_css_class(name) = window.add_css_class(name)
    def remove_css_class(name) = window.remove_css_class(name)
    def focus = window.focus

    private

      def beats_per_page_for(is_tiny)
        if is_tiny
          Constants::NUM_TOGGLES / 2
        else
          Constants::NUM_TOGGLES
        end
      end

      def focus_beat_index(old_beats_per_page)
        if drum_machine_service.playing?
          drum_machine_service.playing_beat
        else
          (drum_grid.carousel&.position.to_i * old_beats_per_page).to_i
        end
      end

      # Upstream writes the class list with an AdwBreakpoint <setter>, but
      # add_setter cannot take a string array through these bindings ("unsupported
      # value type"), so the apply/unapply signals do the same two writes here.
      # Only one breakpoint is applied at a time, so each one sets the whole
      # list and unapply puts the base back — exactly what the setters do.
      def breakpoint(condition, classes, hide_bpm)
        Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(condition)).tap do |point|
          point.signal_connect("apply") do
            drum_machine_box.css_classes = classes
            bpm_label.visible = !hide_bpm
          end

          point.signal_connect("unapply") do
            drum_machine_box.css_classes = BASE_BOX_CLASSES
            bpm_label.visible = true
          end
        end
      end

      def build_header_bar
        header_bar.tap do |bar|
          bar.pack_start(file_pattern_button)
          bar.title_widget = window_title
          bar.pack_end(menu_button)
          bar.pack_end(export_audio_button)

          file_pattern_button.menu_model = pattern_menu.build
          menu_button.menu_model = primary_menu.build
        end
      end

      def build_outer_box
        outer_box.tap do |box|
          box.append(scrolled_window)
          scrolled_window.child = drum_machine_box
        end
      end

      def build_bottom_wrapper
        bottom_wrapper.tap do |wrapper|
          wrapper.append(bpm_box)
          wrapper.append(centre_box)
          wrapper.append(clear_box)

          bpm_box.tap do |box|
            box.append(bpm_label)
            box.append(bpm_spin_button)
          end

          centre_box.tap do |box|
            box.append(play_pause_button)
            box.append(volume_button)
          end

          clear_box.append(clear_button)
        end
      end

      # The close request always reports as handled and routes through the quit
      # action, so the unsaved-changes prompt gets its say.
      def connect_signals
        window.signal_connect("close-request") do
          window_actions.on_quit
          true
        end

        bpm_spin_button.signal_connect("value-changed") { on_bpm_changed }
        volume_button.signal_connect("value-changed") { |_button, value| on_volume_changed(value) }
        clear_button.signal_connect("clicked") { handle_clear }
        play_pause_button.signal_connect("clicked") { handle_play_pause }
        file_pattern_button.signal_connect("clicked") { file_dialogs.handle_open_file }
        export_audio_button.signal_connect("clicked") { file_dialogs.handle_export_audio }
        drum_machine_box.signal_connect("notify::css-classes") { on_breakpoint_changed }
      end
  end
end
