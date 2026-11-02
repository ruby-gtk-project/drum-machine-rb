# frozen_string_literal: true

require "adwaita"

module DrumMachine
  # Style — ported from upstream's src/style.css and src/style-dark.css.
  #
  # Divergence from upstream, recorded deliberately: upstream lists both
  # stylesheets in its GResource but never installs a Gtk.CssProvider for
  # either, so the shipping Python app renders in plain Adwaita colours and the
  # purple theme in data/screenshots/*.png is unreachable. This port loads
  # them, which is what the screenshots show.
  #
  # The dark sheet is layered on top of the light one and only carries the
  # rules that differ, so both providers are installed and the dark one is
  # added and removed as Adwaita::StyleManager flips the dark property.
  module Style
    LIGHT = <<~CSS
      .adw-window {
          background: #D38CFF;
      }

      .drum-machine-box {
          padding: 20px;
          padding-bottom: 15px;
          border-radius: 10px;
          background-color: #ffffff27;
          box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
      }

      .drum-machine-box .drum-toggle {
          background-color: #ffffff65;
      }

      .drum-machine-box .drum-toggle.toggle-active {
          background-color: #ffffff;
          box-shadow: 0 0 10px #ffffff;
      }

      .drum-machine-box .drum-toggle:hover {
          background-color: #ffffffb0;
      }

      .drum-machine-box .drum-toggle:checked {
          background-color: #ffffff;
      }

      .drum-machine-box.medium button {
          min-width: 20px;
          min-height: 20px;
          padding: 4px;
          border-radius: 6px;
      }

      .drum-machine-box.compact button {
          min-width: 10px;
          min-height: 10px;
          padding: 0;
          border-radius: 6px;
      }

      .bottom-wrapper {
          padding: 10px;
      }

      .drum-machine-box.compact .drum-part-button {
          padding-left: 6px;
          padding-right: 6px;
      }

      .disabled {
          opacity: 0.5;
      }

      .drag-over-replace {
          background-color: @accent_bg_color;
          box-shadow: 0 0 15px @accent_bg_color;
          border: 3px solid @accent_bg_color;
          border-radius: 6px;
      }

      /* New drum placeholder styling */
      .new-drum-placeholder button {
          opacity: 0.6;
          color: @accent_color;
      }

      .new-drum-placeholder.highlight button {
          opacity: 1;
          box-shadow: 0 0 10px @accent_color;
          border: 2px solid @accent_color;
      }

      .export-button {
          transition: 200ms ease-in-out;
      }

      .drag-source-active {
          opacity: 0.5;
      }

      /* Remove default GTK drop target outline from column */
      box:drop(active) {
          outline: none;
          box-shadow: none;
          border: none;
      }

      .insert-above {
          box-shadow: 0 -3px 0 0 @accent_color;
      }

      .insert-below {
          box-shadow: 0 3px 0 0 @accent_color;
      }
    CSS

    DARK = <<~CSS
      .adw-window {
          background: #6b369c;
      }

      .drum-machine-box {
          background-color: #00000027;
      }

      .drum-machine-box .drum-toggle.toggle-active {
          background-color: #bf79e7;
          box-shadow: 0 0 10px #bf79e7;
      }

      .drum-machine-box .drum-toggle {
          background-color: #ffffff1c;
      }

      .drum-machine-box .drum-toggle:hover {
          background-color: #ffffff42;
      }

      .drum-machine-box .drum-toggle:checked {
          background-color: #ffffff5e;
      }

      .bottom-wrapper {
          background: #6b369c;
      }
    CSS

    # Priorities: the light sheet sits at APPLICATION, the dark overlay one
    # step above it so its rules win while the dark theme is active.
    LIGHT_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION
    DARK_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION + 1

    # Installs both providers on the default display and keeps the dark one in
    # step with the style manager. Returns the style manager it watched.
    def self.install
      Gdk::Display.default.then do |display|
        if display
          Gtk::StyleContext.add_provider_for_display(display, light_provider, LIGHT_PRIORITY)
          Adwaita::StyleManager.default.tap do |manager|
            manager.signal_connect("notify::dark") { apply_dark(display, manager.dark?) }
            apply_dark(display, manager.dark?)
          end
        end
      end
    end

    def self.apply_dark(display, dark)
      if dark
        Gtk::StyleContext.add_provider_for_display(display, dark_provider, DARK_PRIORITY)
      else
        Gtk::StyleContext.remove_provider_for_display(display, dark_provider)
      end
    end

    def self.light_provider
      @light_provider ||= Gtk::CssProvider.new.tap { |provider| provider.load_from_data(LIGHT) }
    end

    def self.dark_provider
      @dark_provider ||= Gtk::CssProvider.new.tap { |provider| provider.load_from_data(DARK) }
    end
  end
end
