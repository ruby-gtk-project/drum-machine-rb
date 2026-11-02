# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "../drum/machine/rb/version"
require_relative "about_dialog"
require_relative "constants"
require_relative "shortcuts_dialog"
require_relative "style"
require_relative "window"

module DrumMachine
  # Application — ported from upstream's src/application.py and src/main.py.
  #
  # Adwaita::Application is broken in the Ruby bindings, so the application
  # object comes from Gtk and only the window is Adwaita.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APPLICATION_ID = "io.github.revisto.drum-machine"

    # app.about has no accelerator upstream. app.shortcuts does not exist
    # upstream at all — see ShortcutsDialog for why this port installs it.
    ACTIONS = [
      ["about", :on_about, []],
      ["shortcuts", :on_shortcuts, ["<primary>question"]],
    ].freeze

    def initialize(version: Drum::Machine::Rb::VERSION)
      @version = version
    end

    def build
      app.tap do
        app.signal_connect("activate") do
          Adwaita.init
          Style.install
          icon_theme_search_path
          ACTIONS.each { |name, handler, accelerators| create_action(name, handler, accelerators) }

          main_window.tap do |win|
            win.build
            win.present
          end
        end
      end
    end

    def run = app.run([])

    def app = @app ||= Gtk::Application.new(APPLICATION_ID, :default_flags)

    def main_window = @main_window ||= Window.new(app)

    def on_about
      AboutDialog.new(version: @version).tap do |dialog|
        dialog.build
        dialog.present(app.active_window)
      end
    end

    def on_shortcuts
      ShortcutsDialog.new.tap do |dialog|
        dialog.build
        dialog.present(app.active_window)
      end
    end

    private

      # The export button's share-symbolic is a bundled SVG, not a stock icon
      # name, so data/icons goes on the theme's search path.
      def icon_theme_search_path
        Gdk::Display.default.then do |display|
          if display
            Gtk::IconTheme.get_for_display(display).add_search_path(Constants.icons_dir)
          end
        end
      end

      def create_action(name, handler, accelerators)
        Gio::SimpleAction.new(name, nil).tap do |action|
          action.signal_connect("activate") { public_send(handler) }
          app.add_action(action)
          unless accelerators.empty?
            app.set_accels_for_action("app.#{name}", accelerators)
          end
        end
      end
  end
end
