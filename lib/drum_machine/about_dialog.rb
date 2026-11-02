# frozen_string_literal: true

require "adwaita"
require_relative "../drum/machine/rb/version"

module DrumMachine
  # AboutDialog — ported from upstream's src/application.py (on_about_action).
  #
  # Upstream builds the Adw.AboutDialog inline in the action handler; here it
  # is its own class so the fields, the three extra sections and the debug-info
  # string all sit in one place.
  class AboutDialog
    APPLICATION_NAME = "Drum Machine"
    APPLICATION_ICON = "io.github.revisto.drum-machine"
    DEVELOPER_NAME = "Revisto"
    COPYRIGHT = "© 2024–2025 Revisto"
    COMMENTS = "Drum Machine is a modern and intuitive application for creating, " \
               "playing, and managing drum patterns."
    ISSUE_URL = "https://github.com/Revisto/drum-machine/issues"
    WEBSITE = "https://apps.gnome.org/DrumMachine/"
    SOUNDS_LINK = "<a href='https://99sounds.org/drum-samples/'>99Sounds</a>"

    SPECIAL_THANKS = ["Sepehr Rasouli", "Tobias Bernard"].freeze

    def initialize(version: Drum::Machine::Rb::VERSION)
      @version = version
    end

    def build
      dialog.tap do |dlg|
        dlg.add_acknowledgement_section("Special thanks", SPECIAL_THANKS)
        dlg.add_legal_section(
          "Sounds",
          sounds_notice,
          :unknown,
          nil,
        )
        dlg.add_legal_section(
          "Mido",
          nil,
          :mit_x11,
          nil,
        )
        dlg.add_legal_section(
          "Pygame",
          nil,
          :lgpl_2_1,
          nil,
        )
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |dlg|
        dlg.application_name = APPLICATION_NAME
        dlg.application_icon = APPLICATION_ICON
        dlg.developer_name = DEVELOPER_NAME
        dlg.version = @version
        dlg.developers = [DEVELOPER_NAME]
        dlg.copyright = COPYRIGHT
        dlg.comments = COMMENTS
        dlg.debug_info = debug_info
        dlg.license_type = :gpl_3_0
        dlg.translator_credits = "translator-credits"
        dlg.issue_url = ISSUE_URL
        dlg.website = WEBSITE
      end
    end

    def sounds_notice
      format("The drum samples used in this application are from %<link>s.", link: SOUNDS_LINK)
    end

    # The same lines upstream builds, with the Python runtime versions replaced
    # by the Ruby ones. Note Gtk::VERSION does not exist in these bindings; the
    # constant is Gtk::Version.
    def debug_info
      [
        "#{APPLICATION_NAME} #{@version}",
        "System: #{RbConfig::CONFIG["host_os"]}",
        distribution_line,
        "Ruby #{RUBY_VERSION}",
        "GTK #{Gtk::Version::MAJOR}.#{Gtk::Version::MINOR}.#{Gtk::Version::MICRO}",
        "ruby-gnome #{GLib::BINDING_VERSION.join(".")}",
        "Adwaita #{Adwaita::MAJOR_VERSION}.#{Adwaita::MINOR_VERSION}.#{Adwaita::MICRO_VERSION}",
      ].compact.join("\n")
    end

    private

      # Upstream reads platform.freedesktop_os_release()["PRETTY_NAME"] on
      # Linux; the file it reads is /etc/os-release.
      def distribution_line
        ["/etc/os-release", "/usr/lib/os-release"].find { |path| File.readable?(path) }.then do |path|
          if path
            File.readlines(path).grep(/\APRETTY_NAME=/).first.then do |line|
              if line
                "Dist: #{line.split("=", 2).last.strip.delete("\"")}"
              end
            end
          end
        end
      end
  end
end
