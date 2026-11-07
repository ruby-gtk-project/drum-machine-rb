# frozen_string_literal: true

require "gtk4"
require_relative "translation"

module DrumMachine
  # PrimaryMenu — ported from the `menu primary_menu` block in upstream's
  # src/window.ui.
  #
  # Three sections, five items, behind the header bar's hamburger button.
  class PrimaryMenu
    extend Translatable

    SECTIONS = [
      [
        [_("_Add Samples…"), "win.add_samples"],
        [_("_Save Pattern…"), "win.save_pattern"],
      ],
      [
        [_("_Reset to Defaults"), "win.reset_to_defaults"],
      ],
      [
        [_("_Keyboard Shortcuts"), "app.shortcuts"],
        [_("_About Drum Machine"), "app.about"],
      ],
    ].freeze

    def build
      menu.tap do |model|
        SECTIONS.each { |items| model.append_section(nil, section(items)) }
      end
    end

    def menu = @menu ||= Gio::Menu.new

    private

      def section(items)
        Gio::Menu.new.tap do |model|
          items.each { |label, action| model.append(label, action) }
        end
      end
  end
end
