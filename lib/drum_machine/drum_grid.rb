# frozen_string_literal: true

require "adwaita"
require_relative "constants"
require_relative "drum_part_menu"

module DrumMachine
  # DrumGrid — ported from upstream's src/ui/drum_grid_builder.py, including
  # `create_new_drum_placeholder` (the app's only empty/affordance state).
  #
  # The heart of the app, and entirely code-built upstream too: a column of
  # instrument buttons beside a carousel of beat-toggle pages, with the dots
  # indicator under it.
  #
  # Upstream stashes every toggle and instrument button on the window as a
  # dynamic attribute named "<part_id>_toggle_<n>" and reaches them with
  # getattr. This port keeps two explicit registries instead — see #toggle and
  # #instrument_button — and still sets each toggle's widget name to the same
  # string, because the go_to_instrument action parses the part id back out of
  # it.
  class DrumGrid
    INITIAL_PAGES = 2
    MINIMUM_PAGES = 2
    SCROLL_DELAY_MS = 50
    PLACEHOLDER_REVEAL_MS = 100
    PLACEHOLDER_HIDE_MS = 50
    NAME_LIMIT = 11
    COLUMN_SPACING = 10
    COMPACT_COLUMN_SPACING = 12
    PLACEHOLDER_LABEL = "+ New"
    PLACEHOLDER_TOOLTIP = "Drop audio files here to add new drum"

    attr_reader :carousel, :drum_parts_column

    def initialize(window)
      @window = window
      @toggles = {}
      @instrument_buttons = {}
      @carousel = nil
      @drum_parts_column = nil
    end

    def beats_per_page = @window.drum_machine_service.beats_per_page

    # --- registries -----------------------------------------------------

    def toggle(part_id, beat_index) = @toggles[toggle_name(part_id, beat_index)]

    def instrument_button(part_id) = @instrument_buttons[part_id]

    def toggle_name(part_id, beat_index) = "#{part_id}_toggle_#{beat_index}"

    # --- assembly -------------------------------------------------------

    def build
      main_container.tap do |container|
        container.append(horizontal_layout)
        container.append(dots_container)

        horizontal_layout.tap do |layout|
          layout.append(build_drum_parts_column)
          layout.append(carousel_container)
        end

        rebuild_carousel
      end
    end

    def main_container
      @main_container ||= Gtk::Box.new(:vertical, 10).tap { |box| box.name = "main_container" }
    end

    def horizontal_layout
      @horizontal_layout ||= Gtk::Box.new(:horizontal, 10).tap { |box| box.homogeneous = false }
    end

    def carousel_container
      @carousel_container ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.hexpand = true }
    end

    def dots_container
      @dots_container ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.halign = :center }
    end

    # --- carousel -------------------------------------------------------

    # Builds or rebuilds just the carousel and its dots, then puts the pattern
    # back into the fresh toggles and scrolls to the page the caller cares
    # about. The scroll is deferred because the carousel has not been allocated
    # yet when this returns — upstream's 50ms timeout is the same dependency.
    def rebuild_carousel(focus_beat_index: 0)
      @toggles = {}
      build_carousel.then do |carousel|
        dots_indicator(carousel).then do |dots|
          replace_child(carousel_container, carousel)
          replace_child(dots_container, dots)
        end
      end

      @window.drum_machine_service.update_total_beats
      (focus_beat_index / beats_per_page).then do |target_page|
        reset_carousel_pages(target_page)
        @window.ui_helper.load_pattern_into_ui(@window.drum_machine_service.drum_parts_state)
        GLib::Timeout.add(SCROLL_DELAY_MS) do
          scroll_carousel_to_page_safely(target_page)
          false
        end
      end
    end

    # Keeps the carousel as long as the pattern needs plus one spare page, and
    # never shorter than two or than one page past where the user is looking.
    def reset_carousel_pages(current_page_index = -1)
      @carousel.then do |carousel|
        if carousel
          desired_pages(carousel, current_page_index).then do |desired|
            while carousel.n_pages < desired
              carousel.append(beat_grid_page(carousel.n_pages))
            end
            while carousel.n_pages > desired
              carousel.remove(carousel.get_nth_page(carousel.n_pages - 1))
            end
          end
        end
      end
    end

    # --- drum parts column ----------------------------------------------

    def rebuild_drum_parts_column
      @drum_parts_column.then do |column|
        if column
          @instrument_buttons = {}
          while column.first_child
            column.remove(column.first_child)
          end
          drum_parts.each { |drum_part| column.append(instrument_button_container(drum_part)) }
        end
      end
    end

    def update_drum_parts_spacing(is_compact:)
      @drum_parts_column.then do |column|
        if column && is_compact
          column.spacing = COMPACT_COLUMN_SPACING
        elsif column
          column.spacing = COLUMN_SPACING
        end
      end
    end

    # Adds a part to the column and a row for it to every carousel page, so a
    # dropped sample shows up without a full rebuild.
    def add_drum_part(drum_part)
      @drum_parts_column&.append(instrument_button_container(drum_part))

      @carousel.then do |carousel|
        if carousel
          carousel.n_pages.times do |page_index|
            carousel.get_nth_page(page_index).append(drum_row(drum_part.id, page_index))
          end
        end
      end
    end

    # Refreshes one button's label, tooltip and disabled state. A part with no
    # button yet (added while the column was stale) forces a column rebuild.
    def update_drum_button(drum_id)
      drum_part_manager.get_part_by_id(drum_id).then do |drum_part|
        if drum_part.nil?
          warn "drum-machine: drum part not found: #{drum_id}"
        elsif @instrument_buttons.key?(drum_id)
          update_button_content(@instrument_buttons[drum_id], drum_part)
        else
          rebuild_drum_parts_column
        end
      end
    end

    # --- the "+ New" placeholder (the drag-and-drop empty state) ---------

    # Slides a "+ New" row in at the bottom of the column while a file drag is
    # over the window. Returns the revealer, which the drag handler hands back
    # to #remove_new_drum_placeholder on leave or drop.
    def create_new_drum_placeholder
      @drum_parts_column.then do |column|
        if column
          placeholder_revealer.tap do |revealer|
            column.append(revealer)
            revealer.reveal_child = true
          end
        end
      end
    end

    def remove_new_drum_placeholder(placeholder)
      if placeholder && @drum_parts_column && placeholder.parent == @drum_parts_column
        placeholder.transition_duration = PLACEHOLDER_HIDE_MS
        placeholder.reveal_child = false
        GLib::Timeout.add(PLACEHOLDER_HIDE_MS) do
          finish_remove_placeholder(placeholder)
          false
        end
      end
    end

    private

      def drum_part_manager = @window.sound_service.drum_part_manager

      def drum_parts = drum_part_manager.all_parts

      def replace_child(container, child)
        while container.first_child
          container.remove(container.first_child)
        end
        container.append(child)
      end

      def dots_indicator(carousel)
        Adwaita::CarouselIndicatorDots.new.tap do |dots|
          dots.carousel = carousel
          dots.margin_top = 10
        end
      end

      def build_carousel
        Adwaita::Carousel.new.tap do |carousel|
          carousel.spacing = 30
          @carousel = carousel
          carousel.signal_connect("page-changed") { reset_carousel_pages }

          # The carousel's own key handling would page-navigate on Left/Right,
          # which is what the toggles use for moving between beats, so it is
          # swallowed here.
          Gtk::EventControllerKey.new.tap do |controller|
            controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, _state|
              [Gdk::Keyval::KEY_Left, Gdk::Keyval::KEY_Right].include?(keyval)
            end
            carousel.add_controller(controller)
          end

          INITIAL_PAGES.times { |page_index| carousel.append(beat_grid_page(page_index)) }
        end
      end

      def desired_pages(carousel, current_page_index)
        (current_page_index.negative? ? carousel.position.to_i : current_page_index).then do |page_index|
          [
            MINIMUM_PAGES,
            @window.drum_machine_service.active_pages + 1,
            page_index + 2,
          ].max
        end
      end

      def scroll_carousel_to_page_safely(page_index)
        @carousel.then do |carousel|
          if carousel && carousel.n_pages.positive?
            page_index.clamp(0, carousel.n_pages - 1).then do |target_page|
              carousel.scroll_to(carousel.get_nth_page(target_page), true)
            end
          end
        end
      end

      def build_drum_parts_column
        Gtk::Box.new(:vertical, COLUMN_SPACING).tap do |column|
          @drum_parts_column = column
          drum_parts.each { |drum_part| column.append(instrument_button_container(drum_part)) }
          @window.drag_drop.setup_column_reorder_drop_target(column)
        end
      end

      def beat_grid_page(page_index)
        Gtk::Box.new(:vertical, 10).tap do |page|
          drum_parts.each { |drum_part| page.append(drum_row(drum_part.id, page_index)) }
        end
      end

      # One instrument's row of toggles on one page, in groups of four with a
      # gap after every group but the last.
      def drum_row(part_id, page_index)
        Gtk::Box.new(:horizontal, 10).tap do |row|
          beat_group_count.then do |group_count|
            group_count.times do |group_index|
              beat_toggle_group(part_id, group_index, page_index).tap do |group|
                row.append(group)
                unless group_index == group_count - 1
                  group.margin_end = 20
                end
              end
            end
          end
        end
      end

      def beat_group_count
        (beats_per_page + Constants::GROUP_TOGGLE_COUNT - 1) / Constants::GROUP_TOGGLE_COUNT
      end

      def beat_toggle_group(part_id, group_index, page_index)
        Gtk::Box.new(:horizontal, 5).tap do |group|
          Constants::GROUP_TOGGLE_COUNT.times do |position|
            ((group_index * Constants::GROUP_TOGGLE_COUNT) + position + 1).then do |beat_number_on_page|
              if beat_number_on_page <= beats_per_page
                group.append(beat_toggle(part_id, beat_number_on_page, page_index))
              end
            end
          end
        end
      end

      def beat_toggle(part_id, beat_number_on_page, page_index)
        ((page_index * beats_per_page) + (beat_number_on_page - 1)).then do |global_beat_index|
          Gtk::ToggleButton.new.tap do |button|
            button.set_size_request(20, 20)
            button.name = toggle_name(part_id, global_beat_index)
            button.valign = :center
            button.add_css_class("drum-toggle")
            button.signal_connect("toggled") do
              @window.on_toggle_changed(button, part_id, global_beat_index)
            end

            add_toggle_key_controller(button, part_id, global_beat_index)
            add_right_click_gesture(button)
            @toggles[button.name] = button
          end
        end
      end

      def add_toggle_key_controller(button, part_id, global_beat_index)
        Gtk::EventControllerKey.new.tap do |controller|
          controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, _state|
            on_toggle_key_pressed(keyval, part_id, global_beat_index)
          end
          button.add_controller(controller)
        end
      end

      # Right-clicking a beat toggle flips it, the same as a left click.
      def add_right_click_gesture(button)
        Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
          gesture.signal_connect("released") do |_gesture, _n_press, _x, _y|
            @window.on_right_click_released(button)
          end
          button.add_controller(gesture)
        end
      end

      # --- keyboard navigation -------------------------------------------

      def on_toggle_key_pressed(keyval, part_id, global_beat_index)
        case keyval
        when Gdk::Keyval::KEY_Right then handle_right_arrow(part_id, global_beat_index)
        when Gdk::Keyval::KEY_Left then handle_left_arrow(part_id, global_beat_index)
        else false
        end
      end

      def handle_right_arrow(part_id, global_beat_index)
        if ((global_beat_index + 1) % beats_per_page).zero?
          scroll_to_next_page(part_id, global_beat_index)
        else
          navigate_to_target(part_id, global_beat_index, global_beat_index + 1)
        end
      end

      def handle_left_arrow(part_id, global_beat_index)
        if (global_beat_index % beats_per_page).zero?
          scroll_to_previous_page(part_id, global_beat_index)
        else
          navigate_to_target(part_id, global_beat_index, global_beat_index - 1)
        end
      end

      def scroll_to_next_page(part_id, global_beat_index)
        (global_beat_index / beats_per_page).then do |current_page|
          if current_page < @carousel.n_pages - 1
            @carousel.scroll_to(@carousel.get_nth_page(current_page + 1), true)
            focus_target_toggle(part_id, (current_page + 1) * beats_per_page)
          else
            true
          end
        end
      end

      # From the leftmost toggle of page 0, Left goes to the instrument button.
      def scroll_to_previous_page(part_id, global_beat_index)
        (global_beat_index / beats_per_page).then do |current_page|
          if current_page.positive?
            @carousel.scroll_to(@carousel.get_nth_page(current_page - 1), true)
            focus_target_toggle(part_id, ((current_page - 1) * beats_per_page) + (beats_per_page - 1))
          else
            navigate_to_instrument_button(part_id)
          end
        end
      end

      def navigate_to_target(part_id, global_beat_index, target_beat_index)
        scroll_if_needed(global_beat_index, target_beat_index)
        focus_target_toggle(part_id, target_beat_index)
      end

      def scroll_if_needed(global_beat_index, target_beat_index)
        (global_beat_index / beats_per_page).then do |current_page_index|
          (target_beat_index / beats_per_page).then do |target_page_index|
            if current_page_index != target_page_index && target_page_index.between?(0, @carousel.n_pages - 1)
              @carousel.scroll_to(@carousel.get_nth_page(target_page_index), true)
            end
          end
        end
      end

      # Always reports the key as handled, even when the target is not there:
      # letting it fall through would hand Left/Right back to the carousel.
      def focus_target_toggle(part_id, target_beat_index)
        toggle(part_id, target_beat_index)&.grab_focus
        true
      end

      def navigate_to_instrument_button(part_id)
        instrument_button(part_id)&.grab_focus
        true
      end

      # --- instrument buttons --------------------------------------------

      def instrument_button_container(drum_part)
        button_container(drum_button(drum_part))
      end

      def button_container(button)
        Gtk::Box.new(:horizontal, 5).tap do |container|
          container.append(button)
          container.append(spacer)
        end
      end

      def spacer = Gtk::Label.new.tap { |label| label.hexpand = true }

      def drum_button(drum_part)
        button_content(drum_part).then do |label, tooltip|
          base_drum_button(label, tooltip).tap do |button|
            button.signal_connect("clicked") { @window.on_drum_part_button_clicked(drum_part.id) }

            add_instrument_key_controller(button, drum_part.id)
            add_instrument_context_menu(button, drum_part.id)
            apply_button_styling(button, drum_part)

            @instrument_buttons[drum_part.id] = button
            @window.drag_drop.setup_button_drop_target(button, drum_part.id)
            @window.drag_drop.setup_button_reorder_drag_source(button, drum_part.id)
          end
        end
      end

      def base_drum_button(label, tooltip)
        Gtk::Button.new(label: label).tap do |button|
          button.halign = :start
          button.add_css_class("drum-part-button")
          button.add_css_class("flat")
          button.tooltip_text = tooltip
          button.has_tooltip = true
        end
      end

      def add_instrument_key_controller(button, part_id)
        Gtk::EventControllerKey.new.tap do |controller|
          controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, _state|
            on_instrument_button_key_pressed(keyval, part_id)
          end
          button.add_controller(controller)
        end
      end

      # Right from an instrument button jumps into the first toggle of the page
      # the carousel is on.
      def on_instrument_button_key_pressed(keyval, part_id)
        if keyval == Gdk::Keyval::KEY_Right
          focus_target_toggle(part_id, (@carousel.position.to_i * beats_per_page).to_i)
        else
          false
        end
      end

      def add_instrument_context_menu(button, drum_id)
        Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
          gesture.signal_connect("released") do |_gesture, _n_press, _x, _y|
            show_drum_part_context_menu(button, drum_id)
          end
          button.add_controller(gesture)
        end
      end

      def show_drum_part_context_menu(button, drum_id)
        DrumPartMenu.new(window: @window, button: button, drum_id: drum_id).tap do |menu|
          menu.build
          menu.popup
        end
      end

      # The label is truncated so a long custom name cannot stretch the column;
      # the tooltip says what the button really is.
      def button_content(drum_part)
        [display_name(drum_part.name), tooltip_for(drum_part)]
      end

      def display_name(name)
        if name.to_s.length > NAME_LIMIT
          "#{name[0, NAME_LIMIT - 3]}…"
        else
          name.to_s
        end
      end

      def tooltip_for(drum_part)
        if drum_part.temporary?
          "Temporary part: #{drum_part.name} (MIDI Note #{drum_part.midi_note_id})"
        elsif drum_part.file_available?
          "Click to Preview #{drum_part.name}"
        else
          "Missing file: #{drum_part.file_path}"
        end
      end

      def apply_button_styling(button, drum_part)
        if drum_part.file_available?
          button.remove_css_class("disabled")
        else
          button.add_css_class("disabled")
        end
      end

      def update_button_content(button, drum_part)
        button_content(drum_part).then do |label, tooltip|
          button.label = label
          button.tooltip_text = tooltip
        end
        apply_button_styling(button, drum_part)
      end

      # --- placeholder ----------------------------------------------------

      def placeholder_revealer
        Gtk::Revealer.new.tap do |revealer|
          revealer.transition_type = :slide_down
          revealer.transition_duration = PLACEHOLDER_REVEAL_MS
          revealer.child = placeholder_container
        end
      end

      def placeholder_container
        button_container(placeholder_button).tap do |container|
          container.add_css_class("new-drum-placeholder")
        end
      end

      def placeholder_button
        base_drum_button(PLACEHOLDER_LABEL, PLACEHOLDER_TOOLTIP).tap do |button|
          @window.drag_drop.setup_button_drop_target(button)
        end
      end

      def finish_remove_placeholder(placeholder)
        if placeholder.parent == @drum_parts_column
          @drum_parts_column.remove(placeholder)
        end
      end
  end
end
