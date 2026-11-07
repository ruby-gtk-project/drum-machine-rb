# frozen_string_literal: true

require "adwaita"
require_relative "translation"
require_relative "window_actions"

module DrumMachine
  # ShortcutsDialog — ported from upstream's src/gtk/shortcuts-dialog.blp.
  #
  # Divergence from upstream, recorded deliberately: the blueprint has no
  # backing Python file and nothing in the shipping app ever loads it, and the
  # "Keyboard Shortcuts" item in the primary menu points at an app.shortcuts
  # action application.py never installs — so the dialog is unreachable
  # upstream. This port installs app.shortcuts and presents the dialog, which
  # is what the menu item and the blueprint both already advertise.
  #
  # SECTIONS names the action each item's accelerator comes from
  # ("win.foo"/"app.foo", mirroring Adw.ShortcutsItem's own action-name
  # facet) instead of a second, hand-copied accelerator string. The
  # accelerator itself is read at `build` time from whichever table actually
  # binds it — WindowActions::ACTIONS or Application::ACTIONS — so the two
  # tables cannot drift silently; test/drive_main_window.rb asserts they
  # still agree.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    include Translatable

    # Keys and labels here are the plain English upstream's blueprint also
    # uses as the literal msgid under `msgctxt "shortcut window"` — looked up
    # through `p_` in `section`/`item` below, not displayed directly.
    SECTIONS = {
      "General"      => [
        ["Show Shortcuts", "app.shortcuts"],
        ["Quit", "win.quit"],
      ],
      "Playback"     => [
        ["Play/Pause", "win.play_pause"],
        ["Clear All", "win.clear_toggles"],
      ],
      "BPM & Volume" => [
        ["Increase BPM", "win.increase_bpm"],
        ["Decrease BPM", "win.decrease_bpm"],
        ["Increase Volume", "win.increase_volume"],
        ["Decrease Volume", "win.decrease_volume"],
        ["Mute", "win.mute"],
      ],
      "Pattern"      => [
        ["Load Pattern", "win.load_pattern"],
        ["Save Pattern", "win.save_pattern"],
        ["Export Audio", "win.export_audio"],
      ],
      "Navigation"   => [
        ["Go to Instrument", "win.go_to_instrument"],
        ["Previous Page", "win.previous_page"],
        ["Next Page", "win.next_page"],
      ],
    }.freeze

    def initialize
      super()
      self.title = "Keyboard Shortcuts"
    end

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = p_("shortcut window", title)
          items.each { |label, action_name| group.add(item(p_("shortcut window", label), accelerator_for(action_name))) }
        end
      end

      # Positional, not keyword, arguments — even though the error a no-argument
      # new raises advertises the signatures as "title: utf8, accelerator: utf8".
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)

      # "win.foo"/"app.foo" to the accelerator string(s) that prefix's own
      # action table binds, space-joined the way GTK accepts multiple
      # accelerators for one shortcut. Looked up lazily, not at class
      # definition time: Application#require_relative's this file before its
      # own class body runs, so Application::ACTIONS would not exist yet if
      # this were a constant computed at load time.
      def accelerator_for(action_name)
        prefix, name = action_name.split(".", 2)
        table = prefix == "app" ? DrumMachine::Application::ACTIONS : WindowActions::ACTIONS
        _, _, accelerators = table.find { |entry_name, *| entry_name == name }
        accelerators&.join(" ")
      end
  end
end
