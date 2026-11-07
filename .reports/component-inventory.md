# Component inventory — drum-machine upstream vs. `ruby`

Surveyed against `origin/main` (upstream Python/GTK) on 2026-11-07. This is a
map of what exists on each side, unit by unit — not a widget-level
component-parity audit (see the `component-parity` skill for that, run after
this).

## Summary

Upstream is already small (one window, five dialogs/menus, one grid builder,
two interaction handlers). The `ruby` branch's `lib/` already has a
`lib/<thing>.rb` for every upstream unit below — there is no unported unit
left to scaffold. What follows is the file-by-file map so a parity pass knows
where to look.

## Units

| # | Upstream file(s) | Kind | `lib/drum_machine/*.rb` | Exists? |
|---|---|---|---|---|
| 1 | `src/application.py` (`on_about_action`, `create_action`) | application class + actions | `application.rb` | Yes |
| 1b | `src/application.py` → `Adw.AboutDialog` built in `on_about_action` | dialog (about) | `about_dialog.rb` | Yes |
| 2 | `src/window.py` + `src/window.ui` (`<template class="DrumMachineWindow">`) | window | `window.rb` | Yes |
| 3 | `src/window.ui` → `<menu id="primary_menu">` | menu | `primary_menu.rb` | Yes |
| 4 | `src/window.ui` → `<menu id="pattern_menu">` (empty shell) + `src/handlers/file_dialog_handler.py#setup_pattern_menu` (fills it) | menu | `pattern_menu.rb` | Yes |
| 5 | `src/handlers/window_actions.py` (`WindowActionHandler`) | action set (18 `win.*` actions + accelerators) | `window_actions.rb` | Yes |
| 6 | `src/handlers/file_dialog_handler.py` (`FileDialogHandler`, minus `setup_pattern_menu`) | handler — 6 `Gtk.FileDialog` flows (open pattern, save pattern, add samples, replace sample, export-audio save, cover-art pick) | `file_dialogs.rb` | Yes |
| 7 | `src/handlers/drag_drop_handler.py` (`DragDropHandler`) | handler — drop target on window, drop target + drag source per instrument button, string drop target on the column (reorder) | `drag_drop.rb` | Yes |
| 8 | `src/ui/drum_grid_builder.py` (`DrumGridBuilder`), minus the context-menu methods | widget tree — instrument-button column + beat-toggle carousel + dots indicator + "+ New" placeholder (empty/affordance state) | `drum_grid.rb` | Yes |
| 9 | `src/ui/drum_grid_builder.py` → `_show_drum_part_context_menu` and its button callbacks | popover menu (Preview / Replace… / Remove / MIDI Mapping) | `drum_part_menu.rb` | Yes |
| 10 | `src/dialogs/midi_mapping_dialog.py` (`MidiMappingDialog`) | dialog | `midi_mapping_dialog.rb` | Yes |
| 11 | `src/dialogs/audio_export_dialog.py` (`AudioExportDialog`, `ExportMetadata`) + `src/gtk/audio-export-dialog.blp` | dialog + declarative UI | `audio_export_dialog.rb` (+ `export_metadata.rb`) | Yes |
| 12 | `src/dialogs/reset_defaults_dialog.py` + `src/gtk/reset-defaults-dialog.blp` | dialog (`Adw.AlertDialog`) | `reset_defaults_dialog.rb` | Yes |
| 13 | `src/dialogs/save_changes_dialog.py` + `src/gtk/save-changes-dialog.blp` | dialog (`Adw.AlertDialog`) | `save_changes_dialog.rb` | Yes |
| 14 | `src/gtk/shortcuts-dialog.blp` (`Adw.ShortcutsDialog`, no backing `.py` — built straight from the resource) | dialog (shortcuts window) | `shortcuts_dialog.rb` | Yes |
| 15 | `src/utils/export_progress.py` (`ExportProgressHandler`, `ExportTask`) | UI-adjacent helper — drives the export dialog's progress bar/labels | `export_progress.rb` | Yes |

## Non-widget support files (needed for parity, not components themselves)

| Upstream file | Kind | `lib/drum_machine/*.rb` | Exists? |
|---|---|---|---|
| `src/config/constants.py` | constants | `constants.rb` | Yes |
| `src/config/export_formats.py` | data | `export_formats.rb` | Yes |
| `src/models/drum_part.py` | model | `drum_part.rb` | Yes |
| `src/services/drum_machine_service.py` | service | `drum_machine_service.rb` | Yes |
| `src/services/drum_part_manager.py` | service | `drum_part_manager.rb` | Yes |
| `src/services/sound_service.py` | service | `sound_service.rb` | Yes |
| `src/services/pattern_service.py` | service | `pattern_service.rb` | Yes |
| `src/services/save_changes_service.py` | service | `save_changes_service.rb` | Yes |
| `src/services/audio_export_service.py` | service | `audio_export_service.rb` | Yes |
| `src/services/audio_renderer.py` | service | `audio_renderer.rb` | Yes |
| `src/services/file_encoder.py` | service | `file_encoder.rb` | Yes |
| `src/services/ui_helper.py` | service | `ui_helper.rb` | Yes |
| `src/utils/name_utils.py` | util | `name_utils.rb` | Yes |
| `src/style.css` + `src/style-dark.css` | stylesheet | `style.rb` | Yes |
| `src/main.py` / `src/drum-machine.in` | entry point | `exe/`, `lib/drum/machine/rb.rb` (gem scaffold) | Yes |
| gettext plumbing (`gettext()` calls throughout) | i18n | `translation.rb` | Yes |

## Declarative / data files — no `.rb` counterpart needed

| Upstream file | What it is | Status |
|---|---|---|
| `data/io.github.revisto.drum-machine.gschema.xml` | GSettings schema | Empty (`<schema>` with no keys) — nothing to port |
| `src/drum-machine.gresource.xml` | GResource manifest | N/A — the port never has `.ui`/resources by house style; its contents (`window.ui`, the four dialog `.ui`s, the two stylesheets) are all already accounted for above |
| `data/patterns/*.mid` | bundled default patterns | Referenced by `pattern_menu.rb`/`PatternMenu`; data files, copy as-is when packaging |
| `data/drumkit/*.wav` | bundled drum samples | Referenced by `sound_service.rb`; data files, copy as-is when packaging |
| `data/icons/**` | app + export-button icons | Asset files, copy as-is when packaging |
| `data/io.github.revisto.drum-machine.metainfo.xml.in`, `.desktop.in` | AppStream metadata, desktop entry | Packaging metadata, not a UI component |
| `po/*.po` (28 files) + `po/drum-machine.pot` | translation catalogue | `ruby` branch has a `locale/` tree with 29 language directories — counts are close but not yet verified msgid-by-msgid; run `translation-parity` before calling this done |

## What this inventory does NOT verify

Per-widget parity (CSS classes, exact signal wiring, exact action names,
dynamic states like the "Part “X” is Silent" banner text) is not checked here
— that is the `component-parity` skill's job, and it should be run next,
unit by unit, against this list. Likewise `test-parity` (upstream has no
`tests/` directory in this listing — confirm there really is none before
assuming zero is the target) and `translation-parity` (msgid-by-msgid, not
just file counts) are still open.
