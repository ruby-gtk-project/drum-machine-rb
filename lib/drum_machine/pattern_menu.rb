# frozen_string_literal: true

require "gtk4"
require_relative "constants"
require_relative "translation"

module DrumMachine
  # PatternMenu — ported from the `menu pattern_menu` block in upstream's
  # src/window.ui plus file_dialog_handler.setup_pattern_menu, which is what
  # actually fills it.
  #
  # The .ui declares the menu empty and Python replaces it at startup with one
  # section titled "Default Patterns" holding a parameterised win.load-pattern
  # item per bundled pattern. Only the filled shape is worth porting, so this
  # class builds it directly.
  class PatternMenu
    extend Translatable

    SECTION_TITLE = _("Default Patterns")
    ACTION = "win.load-pattern"

    def initialize(patterns: Constants::DEFAULT_PATTERNS)
      @patterns = patterns
    end

    def build
      menu.tap { |model| model.append_section(SECTION_TITLE, section) }
    end

    def menu = @menu ||= Gio::Menu.new

    private

      def section
        Gio::Menu.new.tap do |model|
          @patterns.each { |pattern| model.append_item(item(pattern)) }
        end
      end

      # The pattern name travels as the action's string target, which is what
      # the win.load-pattern action reads back.
      def item(pattern)
        Gio::MenuItem.new(pattern, nil).tap do |menu_item|
          menu_item.set_action_and_target_value(ACTION, GLib::Variant.new(pattern))
        end
      end
  end
end
