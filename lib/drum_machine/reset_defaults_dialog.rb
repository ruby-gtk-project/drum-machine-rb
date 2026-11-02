# frozen_string_literal: true

require "adwaita"

module DrumMachine
  # ResetDefaultsDialog — ported from upstream's
  # src/dialogs/reset_defaults_dialog.py and src/gtk/reset-defaults-dialog.blp.
  #
  # Confirms the win.reset_to_defaults action, which clears the pattern and
  # puts the samples, tempo and volume back where they started.
  class ResetDefaultsDialog
    HEADING = "Reset to Defaults?"
    BODY = "This will clear the current pattern and restore all samples, BPM, and volume to their default values. This action cannot be undone."

    def initialize(window:, on_reset: nil)
      @window = window
      @on_reset = on_reset
    end

    def build
      dialog.tap do |dlg|
        dlg.signal_connect("response::reset") { on_reset }
        dlg.signal_connect("response::cancel") { dlg.close }
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::AlertDialog.new(HEADING, BODY).tap do |dlg|
        dlg.add_response("cancel", "_Cancel")
        dlg.add_response("reset", "_Reset")
        dlg.set_response_appearance("reset", :destructive)
        dlg.close_response = "cancel"
        dlg.default_response = "cancel"
      end
    end

    private

      def on_reset
        @on_reset&.call
        dialog.close
      end
  end
end
