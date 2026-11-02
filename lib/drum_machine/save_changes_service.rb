# frozen_string_literal: true

require_relative "save_changes_dialog"

module DrumMachine
  # SaveChangesService — ported from upstream's
  # src/services/save_changes_service.py.
  #
  # Holds the one flag three dialogs and five actions read: whether the pattern
  # on screen has changes that are not on disk.
  class SaveChangesService
    def initialize(window, drum_machine_service)
      @window = window
      @drum_machine_service = drum_machine_service
      @unsaved_changes = false
    end

    def mark_unsaved_changes(value)
      @unsaved_changes = value
    end

    def unsaved_changes? = @unsaved_changes

    # Opens the confirmation dialog. Saving runs on_save and then clears the
    # flag; discarding runs on_discard untouched; cancelling does neither.
    def prompt_save_changes(on_save:, on_discard:)
      SaveChangesDialog.new(
        window:     @window,
        on_save:    wrap_save(on_save),
        on_discard: on_discard,
      ).tap { |dialog| dialog.build.present(@window.window) }
    end

    private

      def wrap_save(callback)
        lambda do
          callback.call
          mark_unsaved_changes(false)
        end
      end
  end
end
