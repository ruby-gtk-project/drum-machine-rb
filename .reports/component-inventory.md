# Component inventory — drum-machine-rb vs upstream `origin/main`

Surveyed against `origin/main` (Python/GTK, GTK4 + Libadwaita, blueprint
dialogs + one `window.ui`). Port lives on `ruby` in `lib/drum_machine/`.
This is a per-unit map (upstream file(s) → port file, kind, exists?), not a
widget-by-widget scan — see `component-parity` for that pass once a unit is
picked.

Legend for **kind**: `window` / `dialog` / `menu` / `widget-builder` (building
the drum grid widget tree) / `service` (no UI, drives one) / `handler`
(wires actions/signals, no UI of its own) / `model` / `config` / `app`.

## Application shell

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/application.py` | `lib/drum_machine/application.rb` | app | yes |
| `src/application.py` (`on_about_action`, builds `Adw.AboutDialog`) | `lib/drum_machine/about_dialog.rb` | dialog | yes |
| `src/main.py` | (entry point; no `lib/` widget — invoked by `exe/`/bin wrapper, out of scope here) | — | n/a |
| `src/window.py` + `src/window.ui` | `lib/drum_machine/window.rb` | window | yes |
| `src/window.ui` (`primary_menu`) | `lib/drum_machine/primary_menu.rb` | menu | yes |
| `src/window.ui` (`pattern_menu`, populated by `FileDialogHandler.setup_pattern_menu`) | `lib/drum_machine/pattern_menu.rb` | menu | yes |
| `src/handlers/window_actions.py` | `lib/drum_machine/window_actions.rb` | handler | yes |
| `src/handlers/drag_drop_handler.py` | `lib/drum_machine/drag_drop.rb` | handler | yes |
| `src/handlers/file_dialog_handler.py` | `lib/drum_machine/file_dialogs.rb` | handler | yes |
| `src/gtk/shortcuts-dialog.blp` (standalone `Adw.ShortcutsDialog`, no backing source) | `lib/drum_machine/shortcuts_dialog.rb` | dialog | yes |

## Drum grid / instrument list (the main view)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/ui/drum_grid_builder.py` | `lib/drum_machine/drum_grid.rb` | widget-builder | yes |
| `src/ui/drum_grid_builder.py` (`_show_drum_part_context_menu` + its button-row helpers) | `lib/drum_machine/drum_part_menu.rb` | menu | yes |
| `src/services/ui_helper.py` | `lib/drum_machine/ui_helper.rb` | service | yes |

## Dialogs

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/dialogs/audio_export_dialog.py` + `src/gtk/audio-export-dialog.blp` | `lib/drum_machine/audio_export_dialog.rb` | dialog | yes |
| `src/dialogs/midi_mapping_dialog.py` | `lib/drum_machine/midi_mapping_dialog.rb` | dialog | yes |
| `src/dialogs/reset_defaults_dialog.py` + `src/gtk/reset-defaults-dialog.blp` | `lib/drum_machine/reset_defaults_dialog.rb` | dialog | yes |
| `src/dialogs/save_changes_dialog.py` + `src/gtk/save-changes-dialog.blp` | `lib/drum_machine/save_changes_dialog.rb` | dialog | yes |

## Services / models / config (no widgets of their own, but drive the UI above)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/services/drum_machine_service.py` | `lib/drum_machine/drum_machine_service.rb` | service | yes |
| `src/services/drum_part_manager.py` | `lib/drum_machine/drum_part_manager.rb` | service | yes |
| `src/services/sound_service.py` | `lib/drum_machine/sound_service.rb` | service | yes |
| `src/services/audio_export_service.py` | `lib/drum_machine/audio_export_service.rb` | service | yes |
| `src/services/audio_renderer.py` | `lib/drum_machine/audio_renderer.rb` | service | yes |
| `src/services/file_encoder.py` | `lib/drum_machine/file_encoder.rb` | service | yes |
| `src/services/pattern_service.py` | `lib/drum_machine/pattern_service.rb` | service | yes |
| `src/services/save_changes_service.py` | `lib/drum_machine/save_changes_service.rb` | service | yes |
| `src/services/preset_service.py` | — | service | **excluded** — dead code upstream: not listed in `src/services/meson.build`'s `services_sources`, never imported anywhere, and its content is a stale/divergent fork of `pattern_service.py`'s MIDI save/load logic (diffed: same algorithm, missing the `try/except`+logging and type hints `pattern_service.py` has). Not part of the built app; porting it would add a component upstream itself ships dead. |
| `src/interfaces/player.py` | — | interface (ABC) | n/a — a Python ABC with no state and no Ruby duck-typing equivalent needed; not a component |
| `src/interfaces/sound.py` | — | interface (ABC) | n/a — same |
| `src/models/drum_part.py` | `lib/drum_machine/drum_part.rb` | model | yes |
| `src/config/constants.py` | `lib/drum_machine/constants.rb` | config | yes |
| `src/config/export_formats.py` | `lib/drum_machine/export_formats.rb` (+ `export_metadata.rb` for the file's second class) | config | yes |
| `src/utils/export_progress.py` | `lib/drum_machine/export_progress.rb` | model/util | yes |
| `src/utils/name_utils.py` | `lib/drum_machine/name_utils.rb` | util | yes |
| `src/style.css` + `src/style-dark.css` | `lib/drum_machine/style.rb` | config | yes |

## Resources, schema, metadata, catalogue

| Upstream | Port equivalent | Exists? |
|---|---|---|
| `src/drum-machine.gresource.xml` (bundles `style.css`, `style-dark.css`, `window.ui`, the 4 dialog `.ui`s) | n/a by design — the Ruby house style builds every widget declaratively in code (see `ruby-gtk` skill); `style.rb` embeds the CSS text instead of a GResource. No gap: nothing upstream bundles here has no Ruby counterpart. | n/a |
| `data/io.github.revisto.drum-machine.gschema.xml` | **none found in `lib/`** | GSettings schema is effectively empty upstream (`<schema id="io.github.revisto.drum-machine" path="...">` with no `<key>` entries) — nothing to port. |
| `data/io.github.revisto.drum-machine.desktop.in` | no `lib/*.rb` equivalent expected (desktop entry is packaging, not app code) | n/a — flag only if the port ships its own `.desktop`/packaging under `data/`, not checked in this survey |
| `data/io.github.revisto.drum-machine.metainfo.xml.in` (AppStream: description, features list, branding colors, screenshots) | same — packaging/metadata, not `lib/` widget code | n/a, flag for a packaging-parity pass |
| `data/drumkit/*.wav` (10 bundled samples) | referenced by `sound_service.rb`/`drum_part_manager.rb` | not verified bit-for-bit in this pass; same filenames expected under the port's `data/drumkit/` |
| `data/patterns/*.mid` (6 built-in patterns, surfaced via the pattern menu) | referenced by `pattern_menu.rb`/`file_dialogs.rb` | not verified bit-for-bit in this pass |
| `po/*.po` (29 locales in `po/LINGUAS`) + `po/drum-machine.pot` | translation catalogue | **out of scope for this survey** — see the `translation-parity` skill for a dedicated pass; `lib/` strings use `_()`/gettext-equivalent calls that would need the same catalogue wired up |

## Totals

- Upstream user-facing/source files surveyed: 34 (`src/**/*.py`, `src/**/*.blp`, `src/window.ui`)
- Upstream files with no port counterpart needed: 4 (`src/main.py` — entry point; `src/interfaces/player.py`, `src/interfaces/sound.py` — Python ABCs; `src/services/preset_service.py` — dead code, not in the build)
- `lib/drum_machine/*.rb` files: 31 (+ `lib/drum_machine.rb` entry point, + `lib/drum/machine/rb/version.rb` gem-version boilerplate)
- **Every upstream component file that is part of the built app already has a corresponding `lib/*.rb` file on `ruby`.** This survey found no missing component files. What it did not do — by design, "do not write app code" — is verify widget-for-widget, CSS-class-for-CSS-class, signal-for-signal parity inside each existing file; that is the job of `component-parity` run per unit (window → drum grid → each dialog → each menu), and of `test-parity` / `translation-parity` for their respective axes.

## Suggested next units to run `component-parity` on, in the order a user meets them

1. `window.rb` vs `window.py` + `window.ui` (the shell: header bar, breakpoints, bottom transport bar)
2. `drum_grid.rb` vs `drum_grid_builder.py` (the carousel, pages, instrument rows, toggle grid — the biggest single unit, 573 vs 729 lines)
3. `drum_part_menu.rb` vs the context-menu methods in `drum_grid_builder.py`
4. `midi_mapping_dialog.rb` vs `midi_mapping_dialog.py`
5. `audio_export_dialog.rb` vs `audio_export_dialog.py` + `audio-export-dialog.blp`
6. `save_changes_dialog.rb` / `reset_defaults_dialog.rb` vs their `.py` + `.blp` pairs
7. `shortcuts_dialog.rb` vs `shortcuts-dialog.blp`
8. `primary_menu.rb` / `pattern_menu.rb` vs `window.ui`'s two `<menu>` blocks
9. `about_dialog.rb` vs `application.py#on_about_action`
