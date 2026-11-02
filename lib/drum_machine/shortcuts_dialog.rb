# frozen_string_literal: true

require "adwaita"

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
  # Every item names the action its accelerator comes from, and the
  # accelerators are the ones WindowActions actually binds.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      "General"      => [
        ["Show Shortcuts", "<primary>question"],
        ["Quit", "<primary>q"],
      ],
      "Playback"     => [
        ["Play/Pause", "space"],
        ["Clear All", "<primary>Delete"],
      ],
      "BPM & Volume" => [
        ["Increase BPM", "plus"],
        ["Decrease BPM", "minus"],
        ["Increase Volume", "<primary>Up"],
        ["Decrease Volume", "<primary>Down"],
        ["Mute", "<primary>m"],
      ],
      "Pattern"      => [
        ["Load Pattern", "<primary>o"],
        ["Save Pattern", "<primary>s"],
        ["Export Audio", "<primary>e"],
      ],
      "Navigation"   => [
        ["Go to Instrument", "<primary>i"],
        ["Previous Page", "Page_Up"],
        ["Next Page", "Page_Down"],
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
          group.title = title
          items.each { |label, accelerator| group.add(item(label, accelerator)) }
        end
      end

      # Positional, not keyword, arguments — even though the error a no-argument
      # new raises advertises the signatures as "title: utf8, accelerator: utf8".
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end
