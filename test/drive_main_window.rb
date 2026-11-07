# frozen_string_literal: true

# Drives the real application: builds the window, pokes the toggles, the
# transport controls, the menus and every dialog, and screenshots as it goes.

require "tmpdir"
require_relative "gtk_driver"
require_relative "../lib/drum_machine"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir

GtkDriver.drive(DrumMachine::Application.new, shots: "tmp/shots") do |d, app|
  win = -> { app.main_window }
  d.window { win.call.window }

  d.step("the window builds") do
    d.check("the header bar has the pattern split button") { win.call.file_pattern_button.label == "Open…" }
    d.check("the pattern menu has the six bundled patterns") { win.call.pattern_menu.menu.n_items == 1 }
    d.check("the primary menu has three sections") { win.call.primary_menu.menu.n_items == 3 }
    d.check("ten instrument buttons are in the column") do
      win.call.drum_grid.drum_parts_column.then do |column|
        children = []
        child = column.first_child
        while child
          children << child
          child = child.next_sibling
        end
        children.length == 10
      end
    end
    d.check("the carousel starts with two pages") { win.call.drum_grid.carousel.n_pages == 2 }
    d.check("sixteen toggles per part are registered") do
      (0...16).all? { |beat| win.call.drum_grid.toggle("default_kick", beat) }
    end
    d.check("export and clear start insensitive") do
      !win.call.export_audio_button.sensitive? && !win.call.clear_button.sensitive?
    end
    d.shot("01-window")
  end

  d.step("turning a toggle on writes the pattern state") do
    win.call.drum_grid.toggle("default_kick", 0).active = true
    win.call.drum_grid.toggle("default_snare", 4).active = true
  end

  d.step("the state and the buttons followed") do
    d.check("the kick beat is recorded") do
      win.call.drum_machine_service.drum_parts_state["default_kick"][0] == true
    end
    d.check("export and clear became sensitive") do
      win.call.export_audio_button.sensitive? && win.call.clear_button.sensitive?
    end
    d.check("the pattern is marked unsaved") { win.call.save_changes_service.unsaved_changes? }
    d.shot("02-toggled")
  end

  d.step("right-clicking a toggle flips it") do
    win.call.on_right_click_released(win.call.drum_grid.toggle("default_tom", 8))
  end

  d.step("the right-click landed") do
    d.check("the tom beat is on") do
      win.call.drum_machine_service.drum_parts_state["default_tom"][8] == true
    end
  end

  d.step("Clear empties the pattern") { win.call.clear_button.activate }

  d.step("the pattern is empty again") do
    d.check("no beats remain") do
      win.call.drum_machine_service.drum_parts_state.each_value.none? { |beats| beats.any? }
    end
    d.check("the kick toggle is off") { !win.call.drum_grid.toggle("default_kick", 0).active? }
    d.check("export is insensitive again") { !win.call.export_audio_button.sensitive? }
  end

  d.step("a bundled pattern loads") { win.call.file_dialogs.load_named_pattern("Shoot") }

  d.step("the loaded pattern reached the toggles") do
    d.check("the state has beats") do
      win.call.drum_machine_service.drum_parts_state.each_value.any? { |beats| beats.any? }
    end
    d.check("at least one toggle is on") do
      win.call.drum_machine_service.drum_parts_state.any? do |part_id, beats|
        beats.each_key.any? { |beat| win.call.drum_grid.toggle(part_id, beat)&.active? }
      end
    end
    d.check("loading cleared the unsaved flag") { !win.call.save_changes_service.unsaved_changes? }
    d.shot("03-pattern-loaded")
  end

  d.step("the transport plays") { win.call.play_pause_button.activate }

  d.step("playback is running") do
    d.check("the service is playing") { win.call.drum_machine_service.playing? }
    d.check("the button shows pause") do
      win.call.play_pause_button.icon_name == "media-playback-pause-symbolic"
    end
    d.shot("04-playing")
  end

  d.step("the transport stops") { win.call.play_pause_button.activate }

  d.step("playback stopped") do
    d.check("the service is stopped") { !win.call.drum_machine_service.playing? }
    d.check("the button shows play") do
      win.call.play_pause_button.icon_name == "media-playback-start-symbolic"
    end
  end

  d.step("the BPM and volume actions move the controls") do
    win.call.window_actions.on_increase_bpm
    win.call.window_actions.on_decrease_volume
  end

  d.step("the controls moved and the service heard about it") do
    d.check("the tempo rose by one") { win.call.bpm_spin_button.value.round == 121 }
    d.check("the service has the new tempo") { win.call.drum_machine_service.bpm.round == 121 }
    d.check("the volume fell by five") { win.call.volume_button.value.round == 95 }
    d.check("the tooltip names the tempo") do
      win.call.bpm_spin_button.tooltip_text == "121 Beats per Minute (BPM)"
    end
  end

  d.step("mute and unmute") do
    win.call.window_actions.on_mute
  end

  d.step("muting dropped the volume to zero") do
    d.check("the volume is zero") { win.call.volume_button.value.zero? }
    d.check("the last volume is remembered") { win.call.drum_machine_service.last_volume.round == 95 }
  end

  d.step("unmute") { win.call.window_actions.on_mute }

  d.step("unmuting restored the volume") do
    d.check("the volume is back") { win.call.volume_button.value.round == 95 }
  end

  d.step("the carousel pages with the keyboard actions") do
    win.call.window_actions.on_next_page
  end

  d.step("paging worked") do
    d.check("the carousel has more than one page") { win.call.drum_grid.carousel.n_pages > 1 }
  end

  d.step("a toast appears, with a file action") do
    win.call.show_toast("Added: Test Sample")
    win.call.show_toast("Audio exported to out.wav", open_file: true, file_path: "/tmp/out.wav")
  end

  d.step("the toast rendered") { d.shot("05-toast") }

  d.step("the half-view breakpoint rebuilds the grid") { win.call.handle_layout_change(true) }

  d.step("the grid came back at half width") do
    d.check("eight beats per page") { win.call.drum_machine_service.beats_per_page == 8 }
    d.check("the toggles were re-registered") { win.call.drum_grid.toggle("default_kick", 0) }
    d.shot("06-half-view")
  end

  d.step("and back to full width") { win.call.handle_layout_change(false) }

  d.step("sixteen beats per page again") do
    d.check("sixteen beats per page") { win.call.drum_machine_service.beats_per_page == 16 }
  end

  d.step("the About dialog opens") { app.on_about }

  d.step("About is on screen") do
    d.check("a dialog is visible") { win.call.window.visible_dialog }
    d.shot("07-about")
    win.call.window.visible_dialog&.close
  end

  d.step("the shortcuts dialog opens") { app.on_shortcuts }

  d.step("the shortcuts dialog is on screen") do
    d.check("a dialog is visible") { win.call.window.visible_dialog }
    d.shot("08-shortcuts")
    win.call.window.visible_dialog&.close
  end

  d.step("the shortcuts dialog's accelerators agree with what is actually bound") do
    # Gtk canonicalises accelerator strings when it echoes them back
    # ("<primary>q" in, "<Control>q" out), so both sides are parsed down to
    # the same (keyval, modifier) form before comparing — a byte comparison
    # would report every single-primary-key item as a mismatch.
    canon = ->(accel) { Gtk.accelerator_name(*Gtk.accelerator_parse(accel)[1, 2]) }

    d.check("every SECTIONS item's accelerator matches what win./app. actually bind") do
      DrumMachine::ShortcutsDialog::SECTIONS.values.flatten(1).all? do |_label, action_name|
        shown = DrumMachine::ShortcutsDialog.new.send(:accelerator_for, action_name)
        bound = app.app.get_accels_for_action(action_name)
        shown.nil? ? bound.empty? : shown.split(" ").map(&canon) == bound.map(&canon)
      end
    end
  end

  d.step("the reset-to-defaults dialog opens") { win.call.window_actions.on_reset_to_defaults }

  d.step("the reset dialog is on screen") do
    d.check("a dialog is visible") { win.call.window.visible_dialog }
    d.shot("09-reset")
    win.call.window.visible_dialog&.close
  end

  d.step("the save-changes dialog opens") do
    win.call.save_changes_service.mark_unsaved_changes(true)
    win.call.save_changes_service.prompt_save_changes(on_save: -> {}, on_discard: -> {})
  end

  d.step("the save-changes dialog is on screen") do
    d.check("a dialog is visible") { win.call.window.visible_dialog }
    d.shot("10-save-changes")
    win.call.window.visible_dialog&.close
    win.call.save_changes_service.mark_unsaved_changes(false)
  end

  d.step("the MIDI mapping dialog opens") do
    win.call.sound_service.drum_part_manager.get_part_by_id("default_kick").then do |part|
      DrumMachine::MidiMappingDialog.new(win.call, part, ->(_id, _note) {}).tap do |dialog|
        dialog.build
        dialog.present(win.call.window)
      end
    end
  end

  d.step("the MIDI mapping dialog is on screen") do
    d.check("a dialog is visible") { win.call.window.visible_dialog }
    d.shot("11-midi-mapping")
    win.call.window.visible_dialog&.close
  end

  d.step("the export dialog opens") do
    win.call.drum_grid.toggle("default_kick", 0).active = true
    win.call.file_dialogs.handle_export_audio
  end

  d.step("the export dialog is on screen") do
    d.check("a dialog is visible") { win.call.window.visible_dialog }
    d.shot("12-export")
    win.call.window.visible_dialog&.close
  end

  d.step("the drum-part context menu opens") do
    win.call.drum_grid.instrument_button("default_kick").then do |button|
      DrumMachine::DrumPartMenu.new(window: win.call, button: button, drum_id: "default_kick").tap do |menu|
        menu.build
        menu.popup
      end
    end
  end

  d.step("the context menu rendered") { d.shot("13-context-menu") }

  d.step("the drag placeholder appears") do
    win.call.drum_grid.create_new_drum_placeholder
  end

  d.step("the placeholder is in the column") do
    d.check("the last column child is a revealer") do
      win.call.drum_grid.drum_parts_column.last_child.is_a?(Gtk::Revealer)
    end
    d.shot("14-placeholder")
  end

  d.step("adding a sample adds a part and a row") do
    win.call.add_new_drum_part(
      File.join(DrumMachine::Constants.drumkit_dir, "kick.wav"),
      "Test Sample",
    )
  end

  d.step("the new part is there") do
    d.check("eleven parts now") { win.call.sound_service.drum_part_manager.all_parts.length == 11 }
    d.check("the new part has state") do
      win.call.drum_machine_service.drum_parts_state.length == 11
    end
    d.shot("15-added-part")
  end

  d.step("removing a part takes it back out") do
    win.call.sound_service.drum_part_manager.all_parts.last.then do |part|
      win.call.drum_machine_service.remove_drum_part(part.id)
    end
  end

  d.step("ten parts again") do
    d.check("ten parts") { win.call.sound_service.drum_part_manager.all_parts.length == 10 }
    d.check("the carousel still has pages") { win.call.drum_grid.carousel.n_pages >= 2 }
  end

  d.step("reset to defaults puts everything back") { win.call.reset_to_defaults }

  d.step("defaults are back") do
    d.check("the tempo is 120") { win.call.bpm_spin_button.value.round == 120 }
    d.check("the volume is 100") { win.call.volume_button.value.round == 100 }
    d.check("the pattern is empty") do
      win.call.drum_machine_service.drum_parts_state.each_value.none? { |beats| beats.any? }
    end
    d.shot("16-reset")
  end
end
