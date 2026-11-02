# frozen_string_literal: true

require "gtk4"
require_relative "constants"
require_relative "name_utils"

module DrumMachine
  # DragDrop — ported from upstream's src/handlers/drag_drop_handler.py.
  #
  # Four controllers between them: a file drop target on the window (which
  # raises the "+ New" placeholder), one on each instrument button (replace
  # this sample), a drag source on each instrument button and a string drop
  # target on the column (reorder), whose insertion line is pure CSS.
  class DragDrop
    MAX_FILE_SIZE_MB = 50
    BYTES_PER_MB = 1024 * 1024

    attr_reader :new_drum_placeholder

    def initialize(window)
      @window = window
      @new_drum_placeholder = nil
      @dragged_drum_id = nil
    end

    # The window-wide file drop target. Entering it is what tells the app a
    # file drag is in progress at all.
    def setup_drag_drop(target_widget = nil)
      (target_widget || @window).then do |widget|
        Gtk::DropTarget.new(Gdk::FileList.gtype, :copy).tap do |drop_target|
          drop_target.signal_connect("drop") { |_target, value, _x, _y| on_window_drop(value) }
          drop_target.signal_connect("enter") { on_drag_enter }
          drop_target.signal_connect("leave") { clear_drag_feedback }
          widget.add_controller(drop_target)
        end
      end
    end

    def setup_button_drop_target(button, drum_id = nil)
      Gtk::DropTarget.new(Gdk::FileList.gtype, :copy).tap do |drop_target|
        drop_target.signal_connect("drop") do |_target, value, _x, _y|
          handle_multiple_files_drop(files_from(value), drum_id)
        end
        drop_target.signal_connect("enter") do
          button.add_css_class("drag-over-replace")
          Gdk::DragAction::COPY
        end
        drop_target.signal_connect("leave") { button.remove_css_class("drag-over-replace") }
        button.add_controller(drop_target)
      end
    end

    def setup_button_reorder_drag_source(button, drum_id)
      Gtk::DragSource.new.tap do |drag_source|
        drag_source.actions = :move
        drag_source.signal_connect("prepare") { on_reorder_drag_prepare(drum_id) }
        drag_source.signal_connect("drag-begin") { |_source, drag| on_reorder_drag_begin(drag, button) }
        drag_source.signal_connect("drag-end") { on_reorder_drag_end(button) }
        button.add_controller(drag_source)
      end
    end

    def setup_column_reorder_drop_target(column_widget)
      Gtk::DropTarget.new(GLib::Type["gchararray"], :move).tap do |drop_target|
        drop_target.signal_connect("drop") { |_target, value, _x, y| on_column_reorder_drop(value, y) }
        drop_target.signal_connect("motion") { |_target, _x, y| on_column_reorder_motion(y) }
        drop_target.signal_connect("leave") { clear_all_insertion_indicators }
        column_widget.add_controller(drop_target)
      end
    end

    # Replaces one part's sample with a file the user picked from a chooser.
    def handle_replacement_file_selected(file_path, drum_id)
      if file_path.to_s.empty?
        false
      elsif !valid_file?(file_path)
        false
      else
        @window.replace_drum_part(drum_id, file_path, NameUtils.extract_name_from_path(file_path)).then do |result|
          if result
            @window.show_toast("Sound replaced")
            @window.save_changes_service.mark_unsaved_changes(true)
          else
            @window.show_toast("Failed to replace sound")
          end
          result
        end
      end
    end

    # Takes everything dropped at once: the first file replaces the part it was
    # dropped on (if any) and the rest are added as new parts.
    def handle_multiple_files_drop(files, drum_id_to_replace)
      if files.nil? || files.empty?
        false
      else
        partition_files(files).then do |valid_files, skipped_count|
          if valid_files.empty?
            @window.show_toast("No valid audio files found")
            false
          else
            handle_files(valid_files, skipped_count, drum_id_to_replace)
          end
        end
      end
    end

    private

      def files_from(file_list) = file_list.files.map(&:path).compact

      def on_window_drop(value)
        clear_drag_feedback
        handle_multiple_files_drop(files_from(value), nil)
      end

      def on_drag_enter
        @window.add_css_class("drag-hover")
        @new_drum_placeholder = @window.drum_grid.create_new_drum_placeholder
        Gdk::DragAction::COPY
      end

      def clear_drag_feedback
        @window.remove_css_class("drag-hover")
        @new_drum_placeholder.then do |placeholder|
          if placeholder
            @window.drum_grid.remove_new_drum_placeholder(placeholder)
            @new_drum_placeholder = nil
          end
        end
      end

      # --- reordering -----------------------------------------------------

      # The payload is just the part id. Gdk::ContentProvider.new_for_value is
      # not in these bindings, so the string goes over as text/plain, which is
      # what the column's gchararray drop target reads back.
      def on_reorder_drag_prepare(drum_id)
        @dragged_drum_id = drum_id
        Gdk::ContentProvider.new("text/plain", drum_id)
      end

      # Gtk::DragIcon.get_for_drag is not bound; the class-level
      # set_from_paintable is, so the dragged button paints itself as the icon.
      def on_reorder_drag_begin(drag, button)
        button.add_css_class("drag-source-active")
        Gtk::DragIcon.set_from_paintable(
          drag,
          Gtk::WidgetPaintable.new(button),
          0,
          0,
        )
      end

      def on_reorder_drag_end(button)
        button.remove_css_class("drag-source-active")
        @dragged_drum_id = nil
        clear_all_insertion_indicators
      end

      def column_children
        [].tap do |children|
          child = @window.drum_grid.drum_parts_column&.first_child
          while child
            children << child
            child = child.next_sibling
          end
        end
      end

      # Where a drop at this pointer height would land, and the row to draw the
      # insertion line on. The index counts rows whose centre is above y.
      def insertion_index_and_widget(y)
        column_children.then do |children|
          children.index { |child| y < child.allocation.y + (child.height / 2.0) }.then do |index|
            if index
              [index, children[index]]
            else
              [children.length, children.last]
            end
          end
        end
      end

      def on_column_reorder_motion(y)
        if @dragged_drum_id
          clear_all_insertion_indicators
          insertion_index_and_widget(y).then do |insert_index, widget|
            if widget
              column_children.index(widget).then do |widget_index|
                if insert_index > widget_index
                  widget.add_css_class("insert-below")
                else
                  widget.add_css_class("insert-above")
                end
              end
            end
          end
        end
        Gdk::DragAction::MOVE
      end

      def clear_all_insertion_indicators
        column_children.each do |child|
          child.remove_css_class("insert-above")
          child.remove_css_class("insert-below")
        end
      end

      def on_column_reorder_drop(value, y)
        clear_all_insertion_indicators
        value.to_s.then do |source_drum_id|
          if source_drum_id.empty?
            false
          else
            reorder_to(source_drum_id, y)
          end
        end
      end

      def reorder_to(source_drum_id, y)
        @window.sound_service.drum_part_manager.then do |manager|
          manager.get_part_index(source_drum_id).then do |source_index|
            if source_index == -1
              false
            else
              target_index_for(source_index, y).then do |target_index|
                if target_index == source_index
                  false
                else
                  apply_reorder(manager, source_drum_id, target_index)
                end
              end
            end
          end
        end
      end

      # Dropping below your own row shifts every index above you down by one.
      def target_index_for(source_index, y)
        insertion_index_and_widget(y).first.then do |index|
          if source_index < index
            index - 1
          else
            index
          end
        end
      end

      def apply_reorder(manager, source_drum_id, target_index)
        if manager.reorder_part(source_drum_id, target_index)
          @window.drum_grid.rebuild_drum_parts_column
          @window.drum_grid.rebuild_carousel
          true
        else
          false
        end
      end

      # --- validation -----------------------------------------------------

      def valid_file?(path) = validate_file_format(path) && validate_file_access(path)

      def validate_file_format(path)
        if Constants::SUPPORTED_INPUT_AUDIO_FORMATS.include?(File.extname(path).downcase)
          true
        else
          warn "drum-machine: unsupported file format: #{File.extname(path)} for #{File.basename(path)}"
          @window.show_toast("Not a supported audio file")
          false
        end
      end

      def validate_file_access(path)
        if !File.exist?(path)
          @window.show_toast("File not found")
          false
        elsif !File.file?(path)
          @window.show_toast("Selected item is not a file")
          false
        else
          validate_file_size(path)
        end
      end

      def validate_file_size(path)
        (File.size(path) / BYTES_PER_MB.to_f).then do |size_mb|
          if size_mb > MAX_FILE_SIZE_MB
            @window.show_toast(format("File too large: %<size>.1fMB (max %<max>dMB)", size: size_mb, max: MAX_FILE_SIZE_MB))
            false
          else
            true
          end
        end
      end

      def partition_files(files)
        files.partition { |path| valid_file?(path) }.then do |valid_files, skipped|
          [valid_files, skipped.length]
        end
      end

      # --- adding and replacing --------------------------------------------

      def handle_files(valid_files, skipped_count, drum_id_to_replace)
        @success_count = 0
        @replacement_done = false
        @successful_additions = []
        @skipped_count = skipped_count

        valid_files.each_with_index do |path, index|
          process_file(
            path,
            index,
            valid_files.length,
            drum_id_to_replace,
          )
        end

        if valid_files.length > 1
          show_files_notifications
        end

        @success_count.positive?
      end

      def process_file(path, index, file_count, drum_id_to_replace)
        NameUtils.extract_name_from_path(path).then do |name|
          if index.zero? && drum_id_to_replace
            replace_first_file(drum_id_to_replace, path, name)
          else
            add_file(path, name, file_count == 1 && drum_id_to_replace.nil?)
          end
        end
      rescue StandardError => e
        @skipped_count += 1
        @window.show_toast(format("Error processing file: %<error>s", error: e.message))
      end

      def replace_first_file(drum_id, path, name)
        if @window.replace_drum_part(drum_id, path, name)
          @replacement_done = true
          @success_count += 1
        end
      end

      # A single dropped file gets its own "Added: x" toast; several are
      # summarised once at the end instead.
      def add_file(path, name, show_toast)
        if @window.add_new_drum_part(path, name, show_success_toast: show_toast)
          @success_count += 1
          unless show_toast
            @successful_additions << name
          end
        end
      end

      def show_files_notifications
        additions.then do |count|
          if count == 1 && !@successful_additions.empty?
            @window.show_added_toast(@successful_additions.first)
          elsif count.positive?
            @window.show_toast(addition_summary(count))
          elsif @skipped_count.positive? && !@replacement_done
            @window.show_toast(format("%<count>d files skipped", count: @skipped_count))
          end
        end
      end

      def additions
        if @replacement_done
          @success_count - 1
        else
          @success_count
        end
      end

      def addition_summary(count)
        if @skipped_count.positive? && count == 1
          format("Added %<count>d drum part, %<skipped>d files skipped", count: count, skipped: @skipped_count)
        elsif @skipped_count.positive?
          format("Added %<count>d drum parts, %<skipped>d files skipped", count: count, skipped: @skipped_count)
        else
          format("Added %<count>d drum parts", count: count)
        end
      end
  end
end
