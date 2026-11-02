# frozen_string_literal: true

require "adwaita"

module DrumMachine
  # SaveChangesDialog — ported from upstream's
  # src/dialogs/save_changes_dialog.py and src/gtk/save-changes-dialog.blp.
  #
  # Asked before anything that would throw the current pattern away: closing
  # the window, opening a file, picking a default pattern.
  class SaveChangesDialog
    HEADING = "Save Changes?"
    BODY = "Current pattern contains unsaved changes. Changes which are not saved will be permanently lost."

    def initialize(window:, on_save: nil, on_discard: nil)
      @window = window
      @on_save = on_save
      @on_discard = on_discard
    end

    def build
      dialog.tap do |dlg|
        dlg.signal_connect("response::save") { on_save }
        dlg.signal_connect("response::discard") { on_discard }
        dlg.signal_connect("response::cancel") { dlg.close }
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::AlertDialog.new(HEADING, BODY).tap do |dlg|
        dlg.add_response("cancel", "_Cancel")
        dlg.add_response("discard", "_Discard")
        dlg.add_response("save", "_Save")
        dlg.set_response_appearance("discard", :destructive)
        dlg.set_response_appearance("save", :suggested)
        dlg.close_response = "cancel"
        dlg.default_response = "save"
      end
    end

    private

      def on_save
        @on_save&.call
        dialog.close
      end

      def on_discard
        @on_discard&.call
        dialog.close
      end
  end
end
