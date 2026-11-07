# frozen_string_literal: true

require "adwaita"
require_relative "translation"

module DrumMachine
  # MidiMappingDialog — ported from upstream's
  # src/dialogs/midi_mapping_dialog.py.
  #
  # Sets the MIDI note a drum part is written as when a pattern is saved or an
  # audio file exported. The spin button and the preset dropdown drive each
  # other: picking a General MIDI instrument sets the note, and typing a note
  # that is in the GM map selects the instrument.
  class MidiMappingDialog
    include Translatable
    extend Translatable

    # Common GM Percussion Map (General MIDI Level 1).
    GM_PERCUSSION_MAP = {
      35 => _("Acoustic Bass Drum"),
      36 => _("Bass Drum 1"),
      37 => _("Side Stick"),
      38 => _("Acoustic Snare"),
      39 => _("Hand Clap"),
      40 => _("Electric Snare"),
      41 => _("Low Floor Tom"),
      42 => _("Closed Hi Hat"),
      43 => _("High Floor Tom"),
      44 => _("Pedal Hi Hat"),
      45 => _("Low Tom"),
      46 => _("Open Hi Hat"),
      47 => _("Low-Mid Tom"),
      48 => _("Hi-Mid Tom"),
      49 => _("Crash Cymbal 1"),
      50 => _("High Tom"),
      51 => _("Ride Cymbal 1"),
      52 => _("Chinese Cymbal"),
      53 => _("Ride Bell"),
      54 => _("Tambourine"),
      55 => _("Splash Cymbal"),
      56 => _("Cowbell"),
      57 => _("Crash Cymbal 2"),
      58 => _("Vibraslap"),
      59 => _("Ride Cymbal 2"),
      60 => _("Hi Bongo"),
      61 => _("Low Bongo"),
      62 => _("Mute Hi Conga"),
      63 => _("Open Hi Conga"),
      64 => _("Low Conga"),
      65 => _("High Timbale"),
      66 => _("Low Timbale"),
      67 => _("High Agogo"),
      68 => _("Low Agogo"),
      69 => _("Cabasa"),
      70 => _("Maracas"),
      71 => _("Short Whistle"),
      72 => _("Long Whistle"),
      73 => _("Short Guiro"),
      74 => _("Long Guiro"),
      75 => _("Claves"),
      76 => _("Hi Wood Block"),
      77 => _("Low Wood Block"),
      78 => _("Mute Cuica"),
      79 => _("Open Cuica"),
      80 => _("Mute Triangle"),
      81 => _("Open Triangle"),
    }.freeze

    NOTES = GM_PERCUSSION_MAP.keys.sort.freeze
    DEFAULT_NOTE = 36
    CUSTOM_NOTE_SUBTITLE = _("Custom Note")

    def initialize(parent, drum_part, on_save)
      @parent = parent
      @drum_part = drum_part
      @on_save = on_save
    end

    def build
      dialog.tap do |dlg|
        dlg.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scrolled
          view.add_bottom_bar(button_box)

          scrolled.child = content_box

          content_box.tap do |box|
            box.append(preferences_page)

            preferences_page.tap do |page|
              page.add(note_group)
              page.add(preset_group)

              note_group.add(note_row)
              note_row.add_suffix(spin_button)

              preset_group.add(preset_row)
              preset_row.add_suffix(dropdown)
            end
          end

          button_box.tap do |box|
            box.append(save_button)
            save_button.signal_connect("clicked") { on_save_clicked }
          end

          spin_button.signal_connect("value-changed") { on_value_changed }
          dropdown.signal_connect("notify::selected") { on_preset_selected }
        end

        sync_dropdown_to_note(initial_note)
        update_gm_subtitle(initial_note)
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |dlg|
        dlg.title = _("MIDI Mapping")
        dlg.content_width = 450
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.show_title = true }
    end

    def scrolled
      @scrolled ||= Gtk::ScrolledWindow.new.tap do |window|
        window.set_policy(:never, :automatic)
        window.propagate_natural_height = true
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_start = 24
        box.margin_end = 24
      end
    end

    def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

    def note_group
      @note_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _("Note Assignment")
        group.description = pyfmt(
          _("Assign a MIDI note for '{}'. This ensures correct playback when exporting."),
          @drum_part.name,
        )
      end
    end

    def note_row
      @note_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = _("MIDI Note")
        row.subtitle = _("The note number to trigger")
      end
    end

    def adjustment = @adjustment ||= Gtk::Adjustment.new(
      initial_note,
      0,
      127,
      1,
      12,
      0,
    )

    def spin_button
      @spin_button ||= Gtk::SpinButton.new(adjustment, 1, 0).tap do |button|
        button.valign = :center
      end
    end

    def preset_group
      @preset_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _("Standard Instruments")
        group.description = _("Select a General MIDI instrument to automatically set the note.")
      end
    end

    def preset_row
      @preset_row ||= Adwaita::ActionRow.new.tap { |row| row.title = _("Instrument Preset") }
    end

    def preset_model
      @preset_model ||= Gtk::StringList.new(NOTES.map { |note| "#{note} - #{GM_PERCUSSION_MAP[note]}" })
    end

    def dropdown
      @dropdown ||= Gtk::DropDown.new.tap do |widget|
        widget.model = preset_model
        widget.enable_search = true
        widget.valign = :center
      end
    end

    def button_box
      @button_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.halign = :center
        box.margin_bottom = 32
      end
    end

    def save_button
      @save_button ||= Gtk::Button.new(label: _("Save")).tap do |button|
        button.add_css_class("pill")
        button.add_css_class("suggested-action")
      end
    end

    private

      def initial_note = @drum_part.midi_note_id || DEFAULT_NOTE

      def current_note = spin_button.value.to_i

      def on_value_changed
        update_gm_subtitle(current_note)
        sync_dropdown_to_note(current_note)
      end

      # A note the GM map does not name leaves the dropdown unselected, which
      # is what Gtk::INVALID_LIST_POSITION means.
      def sync_dropdown_to_note(note)
        NOTES.index(note).then do |index|
          if index.nil?
            dropdown.selected = Gtk::INVALID_LIST_POSITION
          elsif dropdown.selected != index
            dropdown.selected = index
          end
        end
      end

      def on_preset_selected
        dropdown.selected.then do |index|
          if index != Gtk::INVALID_LIST_POSITION && index < NOTES.length
            NOTES[index].then do |note|
              if current_note != note
                spin_button.value = note
              end
            end
          end
        end
      end

      def update_gm_subtitle(note)
        note_row.subtitle = GM_PERCUSSION_MAP.fetch(note, CUSTOM_NOTE_SUBTITLE)
      end

      def on_save_clicked
        @on_save.call(@drum_part.id, current_note)
        dialog.close
      end
  end
end
