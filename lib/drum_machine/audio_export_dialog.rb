# frozen_string_literal: true

require "adwaita"
require_relative "export_metadata"
require_relative "export_progress"

module DrumMachine
  # AudioExportDialog — ported from upstream's
  # src/dialogs/audio_export_dialog.py and src/gtk/audio-export-dialog.blp.
  #
  # Picks a format and a repeat count, carries the metadata rows, and then
  # shows the export's progress in place: the progress bar pulses over the
  # content, the export button is swapped for a cancel button and the status
  # box names the phase.
  class AudioExportDialog
    DEFAULT_FILENAME = "new_beat"

    def initialize(window:, audio_export_service:, drum_parts_state:, bpm:, suggested_filename: nil)
      @window = window
      @audio_export_service = audio_export_service
      @drum_parts_state = drum_parts_state
      @bpm = bpm
      @suggested_filename = suggested_filename || DEFAULT_FILENAME
    end

    def build
      dialog.tap do |dlg|
        dlg.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.add_top_bar(warning_banner)
          view.content = main_overlay
          view.add_bottom_bar(button_box)

          main_overlay.tap do |overlay|
            overlay.child = scrolled
            overlay.add_overlay(progress_bar)
          end

          scrolled.child = content_box

          content_box.tap do |box|
            box.append(export_group)
            box.append(metadata_group)

            export_group.tap do |group|
              group.add(format_row)
              group.add(repeat_row)
            end

            metadata_group.tap do |group|
              group.add(artist_row)
              group.add(song_row)
              group.add(cover_row)
              cover_row.add_suffix(cover_button)
            end
          end

          button_box.tap do |box|
            box.append(export_button)
            box.append(cancel_button)
            box.append(status_overlay)

            status_overlay.tap do |status|
              status.append(status_label)
              status.append(detail_label)
            end

            export_button.signal_connect("clicked") { on_export_clicked }
            cancel_button.signal_connect("clicked") { on_cancel_clicked }
          end

          cover_button.signal_connect("clicked") { on_cover_button_clicked }
          format_row.signal_connect("notify::selected") { update_metadata_sensitivity }
        end

        dlg.signal_connect("closed") { on_dialog_closed }

        populate_format_list
        update_metadata_sensitivity
        check_temporary_parts
      end
    end

    def present(parent) = dialog.present(parent)

    # --- widgets ---------------------------------------------------------

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |dlg|
        dlg.title = "Export Audio"
        dlg.content_width = 450
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.show_title = true }
    end

    def warning_banner
      @warning_banner ||= Adwaita::Banner.new("").tap { |banner| banner.revealed = false }
    end

    def main_overlay = @main_overlay ||= Gtk::Overlay.new

    def progress_bar
      @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
        bar.valign = :start
        bar.visible = false
        bar.add_css_class("osd")
      end
    end

    def scrolled
      @scrolled ||= Gtk::ScrolledWindow.new.tap do |window|
        window.set_policy(:never, :automatic)
        window.propagate_natural_height = true
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_top = 24
        box.margin_bottom = 24
        box.margin_start = 24
        box.margin_end = 24
      end
    end

    def export_group = @export_group ||= Adwaita::PreferencesGroup.new

    def format_list = @format_list ||= Gtk::StringList.new([])

    def format_row
      @format_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Audio Format"
        row.model = format_list
      end
    end

    def repeat_adjustment = @repeat_adjustment ||= Gtk::Adjustment.new(
      5,
      1,
      100,
      1,
      5,
      0,
    )

    def repeat_row
      @repeat_row ||= Adwaita::SpinRow.new(repeat_adjustment, 1, 0).tap do |row|
        row.title = "Repeat Count"
        row.subtitle = "How many times to repeat the pattern"
      end
    end

    def metadata_group
      @metadata_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = "Metadata" }
    end

    def artist_row
      @artist_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Artist Name"
        row.show_apply_button = false
      end
    end

    def song_row
      @song_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Song Name"
        row.show_apply_button = false
      end
    end

    def cover_row
      @cover_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Cover Art"
        row.activatable_widget = cover_button
      end
    end

    def cover_button
      @cover_button ||= Gtk::Button.new(label: ExportMetadata::CHOOSE_FILE_LABEL).tap do |button|
        button.valign = :center
      end
    end

    def button_box
      @button_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.halign = :center
        box.margin_start = 24
        box.margin_end = 24
        box.margin_top = 16
        box.margin_bottom = 32
      end
    end

    def export_button
      @export_button ||= Gtk::Button.new(label: "Export Audio").tap do |button|
        button.add_css_class("suggested-action")
        button.add_css_class("pill")
      end
    end

    def cancel_button
      @cancel_button ||= Gtk::Button.new(label: "Cancel Export").tap do |button|
        button.add_css_class("destructive-action")
        button.add_css_class("pill")
        button.visible = false
      end
    end

    def status_overlay
      @status_overlay ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.halign = :center
        box.visible = false
      end
    end

    def status_label
      @status_label ||= Gtk::Label.new("Exporting…").tap do |label|
        label.halign = :center
        label.add_css_class("heading")
      end
    end

    def detail_label
      @detail_label ||= Gtk::Label.new("Processing…").tap do |label|
        label.halign = :center
        label.add_css_class("caption")
      end
    end

    # --- components ------------------------------------------------------

    def metadata_manager
      @metadata_manager ||= ExportMetadata.new(
        artist_row,
        song_row,
        cover_row,
        cover_button,
      )
    end

    def progress_handler
      @progress_handler ||= ExportProgressHandler.new(
        progress_bar,
        status_overlay,
        status_label,
        detail_label,
      )
    end

    def export_task = @export_task ||= ExportTask.new(@audio_export_service, progress_handler)

    private

      def populate_format_list
        @audio_export_service.format_registry.all_formats.keys.sort.each do |format_id|
          format_list.append(@audio_export_service.format_registry.get_format(format_id).display)
        end
      end

      def selected_format = @audio_export_service.format_registry.get_format(format_row.selected)

      # WAV carries no tags, so its metadata rows go insensitive.
      def update_metadata_sensitivity
        metadata_manager.sensitive = selected_format.supports_metadata?
      end

      # A part a loaded pattern invented has no sample behind it, so its beats
      # export silent; the banner says which ones.
      def check_temporary_parts
        silent_part_names.then do |names|
          if names.empty?
            warning_banner.revealed = false
          else
            warning_banner.title = silent_message(names)
            warning_banner.revealed = true
          end
        end
      end

      def silent_part_names
        @drum_parts_state.filter_map do |part_id, part_state|
          @window.sound_service.drum_part_manager.get_part_by_id(part_id).then do |part|
            if part&.temporary? && part_state.each_value.any? { |active| active }
              part.name
            end
          end
        end
      end

      def silent_message(names)
        case names.length
        when 1 then format("Part “%<first>s” is Silent", first: names.first)
        when 2 then format("Parts “%<first>s” and “%<second>s” are Silent", first: names.first, second: names[1])
        else format("%<count>d Parts are Silent", count: names.length)
        end
      end

      def on_cover_button_clicked
        @window.file_dialogs.open_cover_art_chooser do |path|
          metadata_manager.set_cover_art(path)
        end
      end

      def on_export_clicked
        @window.file_dialogs.save_audio_dialog(selected_format, initial_name).then do |dialog|
          dialog.save(@window.window) do |dlg, result|
            begin
              dlg.save_finish(result).then do |file|
                if file
                  start_export(file.path)
                end
              end
            rescue GLib::Error => e
              warn "drum-machine: save dialog cancelled or failed: #{e.message}"
            end
          end
        end
      end

      def initial_name = "#{metadata_manager.title || @suggested_filename}#{selected_format.ext}"

      def start_export(filename)
        disable_export_controls
        export_task.start_export(
          @drum_parts_state,
          @bpm,
          filename,
          repeat_row.value.to_i,
          metadata_manager.metadata,
          method(:on_export_complete),
        )
      end

      def disable_export_controls
        format_row.sensitive = false
        repeat_row.sensitive = false
        metadata_manager.sensitive = false
        export_button.visible = false
        cancel_button.visible = true
      end

      def on_export_complete(success, filename)
        if success
          @window.show_toast(
            format("Audio exported to %<name>s", name: File.basename(filename)),
            open_file: true,
            file_path: filename,
          )
        else
          @window.show_toast("Export failed")
        end
        dialog.close
      end

      def on_cancel_clicked
        export_task.cancel_export
        @window.show_toast("Export cancelled successfully")
        dialog.close
      end

      def on_dialog_closed
        export_task.cancel_export
        progress_handler.stop_progress_tracking
      end
  end
end
