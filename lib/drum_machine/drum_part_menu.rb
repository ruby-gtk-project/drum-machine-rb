# frozen_string_literal: true

require "gtk4"
require_relative "midi_mapping_dialog"

module DrumMachine
  # DrumPartMenu — ported from `_show_drum_part_context_menu` and its handlers
  # in upstream's src/ui/drum_grid_builder.py.
  #
  # The popover a right-click on an instrument button raises: preview, replace,
  # remove, and the MIDI mapping dialog. "Remove" is insensitive while only one
  # drum part is left, and says so in its tooltip.
  class DrumPartMenu
    REPLACE_TOOLTIP = "Replace with new sound"
    REMOVE_DISABLED_TOOLTIP = "At least one drum part must remain"
    MIDI_TOOLTIP = "Configure MIDI note for export"
    REPLACE_DIALOG_TITLE = "Select New Sound"

    def initialize(window:, button:, drum_id:)
      @window = window
      @button = button
      @drum_id = drum_id
    end

    def build
      popover.tap do |menu|
        menu.parent = @button
        menu.child = menu_box

        # The popover is parented on the button for as long as it is up; left
        # attached it would outlive the button and GTK would complain about
        # finalizing a widget that still has children.
        menu.signal_connect("closed") { menu.unparent }

        menu_box.tap do |box|
          box.append(preview_button)
          box.append(replace_button)
          box.append(remove_button)
          box.append(separator)
          box.append(midi_mapping_button)

          preview_button.signal_connect("clicked") { on_preview }
          replace_button.signal_connect("clicked") { on_replace }
          midi_mapping_button.signal_connect("clicked") { on_midi_mapping }

          if removable?
            remove_button.signal_connect("clicked") { on_remove }
          end
        end
      end
    end

    def popup = popover.popup

    def popover = @popover ||= Gtk::Popover.new

    def menu_box = @menu_box ||= Gtk::Box.new(:vertical, 0)

    def separator = @separator ||= Gtk::Separator.new(:horizontal)

    def preview_button = @preview_button ||= menu_button("Preview")

    def replace_button
      @replace_button ||= menu_button("Replace…").tap do |button|
        button.tooltip_text = REPLACE_TOOLTIP
      end
    end

    def remove_button
      @remove_button ||= menu_button("Remove").tap do |button|
        button.sensitive = removable?
        unless removable?
          button.tooltip_text = REMOVE_DISABLED_TOOLTIP
        end
      end
    end

    def midi_mapping_button
      @midi_mapping_button ||= menu_button("MIDI Mapping").tap do |button|
        button.tooltip_text = MIDI_TOOLTIP
      end
    end

    private

      def menu_button(label)
        Gtk::Button.new(label: label).tap { |button| button.add_css_class("flat") }
      end

      def drum_part_manager = @window.sound_service.drum_part_manager

      def removable? = drum_part_manager.all_parts.length > 1

      def on_preview
        @window.drum_machine_service.preview_drum_part(@drum_id)
        popover.popdown
      end

      def on_replace
        popover.popdown
        @window.file_dialogs.open_audio_file_chooser(REPLACE_DIALOG_TITLE) do |path|
          @window.drag_drop.handle_replacement_file_selected(path, @drum_id)
        end
      end

      def on_midi_mapping
        popover.popdown
        drum_part_manager.get_part_by_id(@drum_id).then do |drum_part|
          if drum_part
            MidiMappingDialog.new(@window, drum_part, method(:on_midi_mapping_save)).tap do |dialog|
              dialog.build
              dialog.present(@window.window)
            end
          end
        end
      end

      def on_midi_mapping_save(drum_id, note)
        if drum_part_manager.update_part_midi_note(drum_id, note)
          @window.show_toast("MIDI note updated")
          @window.drum_grid.update_drum_button(drum_id)
        end
      end

      def on_remove
        drum_part_manager.get_part_by_id(@drum_id).then do |drum_part|
          (drum_part ? drum_part.name : @drum_id).then do |drum_name|
            if @window.drum_machine_service.remove_drum_part(@drum_id)
              @window.show_toast(format("Removed drum part: %<name>s", name: drum_name))
              @window.save_changes_service.mark_unsaved_changes(true)
              @window.update_export_button_sensitivity
            else
              @window.show_toast("Failed to remove drum part")
            end
          end
        end
        popover.popdown
      end
  end
end
