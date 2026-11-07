# drum-machine — upstream component inventory

Survey for the full-parity Ruby GTK4/Libadwaita port.

- **Upstream**: `origin/main` in this repo — Python/PyGObject, GTK 4 + libadwaita 1,
  `Gtk.Template` against `src/window.ui` and three blueprint files, plus one
  standalone blueprint (`shortcuts-dialog.blp`).
- **Port**: the `ruby` branch. `lib/` holds 33 files / 5,456 lines across
  `lib/drum_machine/*.rb` (plus `lib/drum_machine.rb` and
  `lib/drum/machine/rb/version.rb`). **Every component below now has its
  `lib/*.rb` file**; this revision re-surveys upstream and marks the port side
  against the tree as it stands after `90a3ede` ("Port the window, grid,
  services and dialogs from Python").
- **Method**: `component-identification` skill. Declarative UI read first
  (`src/window.ui`, `src/gtk/*.blp`), then every Python file that builds or
  drives a widget, then the two stylesheets, the GResource manifest, the
  GSettings schema and `po/`.
- **Target naming**: the pilot port (`gnome-contacts-rb`) uses flat
  `lib/<thing>.rb` with top-level classes. This fork's skeleton, gemspec and
  `exe/drum-machine` already use the `DrumMachine::` namespace under
  `lib/drum_machine/`, so targets below are written as
  `lib/drum_machine/<thing>.rb`. See blocker 1.

## Shape of the upstream app

One `Adw.ApplicationWindow` (1000×800, min 360×420, four `AdwBreakpoint`s), a
header bar with an `AdwSplitButton` for patterns, an export button and a menu
button, a centred drum grid built entirely in Python inside an `Adw.Carousel`,
and a bottom bar with BPM spin button, a 60×60 circular play/pause button, a
`GtkScaleButton` volume control and a Clear button. Four dialogs (export,
MIDI mapping, reset-to-defaults, save-changes), one keyboard-shortcuts
blueprint, two menu models, one right-click popover, one drag-and-drop
placeholder, and six `Gtk.FileDialog` flows.

Totals: 1 window, 5 dialogs (incl. About), 2 menu models, 1 popover menu,
18 window actions + 1 app action + 2 parameterised actions, 6 file dialogs,
~19 distinct CSS classes across the two stylesheets, 28 translated locales.

---

## 1. `src/application.py` (+ `src/main.py`) — the application object

Target: `lib/drum_machine/application.rb` — **exists**.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate` | id `io.github.revisto.drum-machine`, `DEFAULT_FLAGS` |
| — | — | — | action `app.about` | `create_action("about", …)`; no accel |

`do_activate` creates one `DrumMachineWindow` and presents it; a failure to
build the window is logged `critical` and re-raised. `create_action(name,
callback, shortcuts)` is the generic helper (`app.<name>` accels).

Port note: `Adwaita::Application` is broken in the Ruby bindings — the existing
skeleton already uses `Gtk::Application` with an `Adwaita::ApplicationWindow`.
Keep that.

## 2. `src/application.py` → `on_about_action` — About dialog

Target: `lib/drum_machine/about_dialog.rb` — **exists**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | presented on `app.about` | see fields below |

Fields: application name _"Drum Machine"_, icon
`io.github.revisto.drum-machine`, developer "Revisto", version, developers
`["Revisto"]`, copyright `© 2024–2025 Revisto`, comments _"Drum Machine is a
modern and intuitive application for creating, playing, and managing drum
patterns."_, `license_type` GPL-3.0, `translator_credits` = `_("translator-credits")`,
issue URL `github.com/Revisto/drum-machine/issues`, website
`apps.gnome.org/DrumMachine/`.

Extra sections, all of which are components a reviewer will look for:
- acknowledgement section _"Special thanks"_ → `["Sepehr Rasouli", "Tobias Bernard"]`
- legal section _"Sounds"_ → _"The drum samples used in this application are from {link}."_
  with `<a href='https://99sounds.org/drum-samples/'>99Sounds</a>`, `License.UNKNOWN`
- legal section "Mido" → MIT_X11
- legal section "Pygame" → LGPL_2_1

`debug_info` is a built string: version, `platform.system()`, freedesktop
`PRETTY_NAME` on Linux, Python version, GTK version, PyGObject version,
Adwaita version. The Ruby equivalent must use `Gtk::Version` (there is no
`Gtk::VERSION`).

## 3. `src/window.py` + `src/window.ui` — the main window

Target: `lib/drum_machine/window.rb` — **exists**.

| Widget | × | CSS | Signals / handler | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template `DrumMachineWindow`) | 1 | `adw-window` | `close-request` → `_on_close_request` | 1000×800, width-request 360, height-request 420 |
| `Adw.Breakpoint` | 4 | sets `drum-machine-box` + `medium` / `compact` / `half-view` | — | `max-width: 890px or max-height: 625px`; `max-width: 740px or max-height: 560px`; `max-width: 500px`; `max-width: 395px` (also hides `bpm_label`) |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | `add_toast` | host for every toast |
| `Adw.ToolbarView` | 1 | — | — | top header bar, bottom wrapper |
| `Adw.HeaderBar` `header_bar` | 1 | — | — | |
| `Adw.SplitButton` `file_pattern_button` | 1 | — | `clicked` → `_on_open_file_clicked` | label _"Open…"_, `use-underline`, tooltip _"Open Pattern"_, menu-model `pattern_menu`; a11y label _"Open Pattern"_ / description _"Open Saved Drum Pattern"_ |
| `Adw.WindowTitle` | 1 | — | — | title _"Drum Machine"_ |
| `Gtk.MenuButton` `menu_button` | 1 | — | `activate()` from `win.open_menu` | icon `open-menu-symbolic`, menu-model `primary_menu`, tooltip _"Main Menu"_, a11y description _"Access Keyboard Shortcuts and Application Information"_ |
| `Gtk.Button` `export_audio_button` | 1 | `export-button` | `clicked` → `_on_export_audio_clicked` | icon `share-symbolic` (bundled SVG, see §21), tooltip _"Export Audio…"_, sensitivity driven by `update_export_button_sensitivity` |
| `Gtk.Box` `outer_box` | 1 | — | — | vertical |
| `Gtk.ScrolledWindow` | 1 | — | — | vexpand + hexpand |
| `Gtk.Box` `drum_machine_box` | 1 | `drum-machine-box` (+ `medium`/`compact`/`half-view` from breakpoints) | `notify::css-classes` → `_on_breakpoint_changed` | centred, spacing 12, 12px margins; **the breakpoint signal is the whole responsive mechanism** |
| `Gtk.Box` `bottom_wrapper` | 1 | `bottom-wrapper` | — | bottom bar |
| `Gtk.Box` `bpm_box` | 1 | — | — | halign start, spacing 6 |
| `Gtk.Label` `bpm_label` | 1 | — | — | _"BPM"_; hidden below 395px |
| `Gtk.SpinButton` `bpm_spin_button` | 1 | — | `value-changed` → `on_bpm_changed` | adjustment 30–300, step 1, page 10, value 120; tooltip _"Adjust Tempo In Beats per Minute (BPM)"_ rewritten on change to _"{} Beats per Minute (BPM)"_; a11y label _"Tempo"_ |
| `Gtk.Box` (centre) | 1 | — | — | hexpand, halign center, spacing 12 |
| `Gtk.Button` `play_pause_button` | 1 | `circular` | `clicked` → `handle_play_pause` | 60×60; icon toggles `media-playback-start-symbolic` ⇄ `media-playback-pause-symbolic`, tooltip _"Play"_ ⇄ _"Pause"_ |
| `Gtk.ScaleButton` `volume_button` | 1 | — | `value-changed` → `on_volume_changed` | icons `audio-volume-muted/high/low/medium-symbolic`; adjustment 0–100 step 1 page 5 value 100; tooltip _"Adjust Volume"_ → _"{:.0f}% Volume"_ |
| `Gtk.Box` `clear_box` | 1 | — | — | halign end |
| `Gtk.Button` `clear_button` | 1 | — | `clicked` → `handle_clear` | label _"Clear"_, tooltip _"Clear the Drum Pattern"_; sensitivity from `update_export_button_sensitivity` |
| `Gtk.Adjustment` | 2 | — | — | type, not widget — BPM and volume |

Behaviour the port has to carry:
- `update_export_button_sensitivity` — export **and** clear are insensitive
  when no beat is active anywhere.
- `_on_breakpoint_changed` reads `css-classes`: `half-view` → `beats_per_page =
  NUM_TOGGLES // 2` (8) and a full carousel rebuild focused on the playing beat
  (or the current page × old beats-per-page); `compact` → drum-parts column
  spacing 12 instead of 10.
- `handle_clear`, `reset_to_defaults` (clear + default samples + BPM 120 +
  volume 100 + rebuild both column and carousel).
- `on_toggle_changed` writes/pops `drum_parts_state[part][index]`, recomputes
  total beats, updates sensitivity, marks unsaved.
- `_on_right_click_released` — right-click on a beat toggle flips it and emits
  `toggled` manually.
- `_on_close_request` always returns `true` and routes through `win.quit`.
- `show_toast(message, open_file:, file_path:)` — `Adw.Toast` timeout 5; with a
  file it lazily installs a `win.open-file` action taking a string, sets the
  button label _"Open"_ and launches the default handler for `file://…`.
  Toast strings: _"Added: {}"_, _"Failed to add custom sound"_,
  _"Replaced drum with: {}"_, _"Failed to replace drum sound"_.
- `scroll_carousel_to_page`.

## 4. `src/window.ui` → `menu primary_menu` — primary menu

Target: `lib/drum_machine/primary_menu.rb` — **exists**.

`Gio.Menu`, three sections, five items:

| Item | Action |
|---|---|
| _"_Add Samples…"_ | `win.add_samples` |
| _"_Save Pattern…"_ | `win.save_pattern` |
| _"_Reset to Defaults"_ | `win.reset_to_defaults` |
| _"_Keyboard Shortcuts"_ | `app.shortcuts` |
| _"_About Drum Machine"_ | `app.about` |

## 5. `src/window.ui` → `menu pattern_menu` + `file_dialog_handler.setup_pattern_menu` — pattern menu

Target: `lib/drum_machine/pattern_menu.rb` — **exists**.

The `.ui` declares an empty `pattern_menu`; Python replaces it at startup with
a `Gio.Menu` holding one section titled _"Default Patterns"_ and one
`Gio.MenuItem` per entry in `DEFAULT_PATTERNS`, each targeting
`win.load-pattern` with the pattern name as a string variant.

Repeater: 6 items — _"Shoot"_, _"Maybe Rock"_, _"Boom Boom"_, _"Night"_,
_"Slow"_, _"Chill"_, resolved to `data/patterns/<name>.mid`.

## 6. `src/gtk/shortcuts-dialog.blp` — keyboard shortcuts dialog

Target: `lib/drum_machine/shortcuts_dialog.rb` — **exists**.

A standalone `Adw.ShortcutsDialog` named `shortcuts_dialog` with **no backing
source file** — 6 `Adw.ShortcutsSection`, 15 `Adw.ShortcutsItem`, all strings
in the `shortcut window` gettext context:

| Section | Items (action-name) |
|---|---|
| General | Show Shortcuts (`app.shortcuts`), Quit (`win.quit`) |
| Playback | Play/Pause (`win.play_pause`), Clear All (`win.clear_toggles`) |
| BPM & Volume | Increase BPM (`win.increase_bpm`), Decrease BPM (`win.decrease_bpm`), Increase Volume (`win.increase_volume`), Decrease Volume (`win.decrease_volume`), Mute (`win.mute`) |
| Pattern | Load Pattern (`win.load_pattern`), Save Pattern (`win.save_pattern`), Export Audio (`win.export_audio`) |
| Navigation | Go to Instrument (`win.go_to_instrument`), Previous Page (`win.previous_page`), Next Page (`win.next_page`) |

See blockers 3 and 4: upstream never installs `app.shortcuts` and never loads
this `.ui`, and `win.load_pattern` here does not match the `win.load-pattern`
the pattern menu installs.

## 7. `src/handlers/window_actions.py` — window actions and accelerators

Target: `lib/drum_machine/window_actions.rb` — **exists**.

18 `Gio.SimpleAction`s installed in a loop, so **none of them appears in a
scan of literals** — the full list:

| Action | Accel | Does |
|---|---|---|
| `open_menu` | `F10` | `menu_button.activate()` |
| `play_pause` | `space` | `window.handle_play_pause` |
| `clear_toggles` | `<primary>Delete` | `window.handle_clear` |
| `increase_bpm` | `plus`, `equal` | spin +1 |
| `decrease_bpm` | `minus` | spin −1 |
| `increase_volume` | `<primary>Up` | `min(v+5, 100)` |
| `decrease_volume` | `<primary>Down` | `max(v−5, 0)` |
| `load_pattern` | `<primary>o` | open-file flow |
| `save_pattern` | `<primary>s` | save-pattern flow |
| `export_audio` | `<primary>e` | export dialog |
| `add_samples` | `<primary><shift>a` | add-samples file chooser |
| `reset_to_defaults` | — | `ResetDefaultsDialog` |
| `quit` | `<primary>q` | unsaved-changes check, then destroy |
| `close_window` | `<primary>w` | same handler as `quit` |
| `go_to_instrument` | `<primary>i` | focus the instrument button of the focused toggle, parsed out of the widget name `<part>_toggle_<n>` |
| `previous_page` | `Page_Up` | carousel scroll −1 |
| `next_page` | `Page_Down` | carousel scroll +1 |
| `mute` | `<primary>m` | 0 ⇄ `last_volume` |

Plus two parameterised actions installed elsewhere: `win.load-pattern` (`s`,
in `file_dialog_handler`) and `win.open-file` (`s`, in `window.py`).

## 8. `src/ui/drum_grid_builder.py` — the drum grid

Target: `lib/drum_machine/drum_grid.rb` — **exists**. The largest unit (≈700
lines) and the heart of the app. Entirely code-built; no `.ui`.

| Widget | × | CSS | Signals / controllers | Notes |
|---|---:|---|---|---|
| `Gtk.Box` `main_container` | 1 | — | — | vertical, spacing 10, name `main_container` |
| `Gtk.Box` horizontal_layout | 1 | — | — | spacing 10, not homogeneous |
| `Gtk.Box` drum_parts_column | 1 | — | reorder `Gtk.DropTarget` | spacing 10 (12 when `compact`) |
| `Gtk.Box` carousel_container | 1 | — | — | hexpand |
| `Gtk.Box` dots_container | 1 | — | — | halign center |
| `Adw.Carousel` | 1 | — | `page-changed` → `_on_page_changed`; `Gtk.EventControllerKey` swallowing Left/Right | spacing 30, min 2 pages, grown/shrunk by `reset_carousel_pages` |
| `Adw.CarouselIndicatorDots` | 1 | — | — | margin-top 10 |
| `Gtk.Box` beat-grid page | *repeater* | — | — | one per carousel page, vertical spacing 10 |
| `Gtk.Box` instrument_container (drum row) | *repeater* | — | — | one per part per page, horizontal spacing 10 |
| `Gtk.Box` beat_group | *repeater* | — | — | `ceil(beats_per_page / 4)` per row, spacing 5, `margin-end 20` except the last |
| `Gtk.ToggleButton` beat toggle | *repeater* | `drum-toggle`, + `toggle-active` (playhead, added by `ui_helper`) | `toggled` → `window.on_toggle_changed`; `Gtk.EventControllerKey` → `_on_toggle_key_pressed`; `Gtk.GestureClick` (BUTTON_SECONDARY) → `window._on_right_click_released` | 20×20, valign center, widget name `<part_id>_toggle_<global_index>`, also stashed on the window as an attribute |
| `Gtk.Button` instrument button | *repeater* | `drum-part-button`, `flat`, + `disabled` when the sample file is missing | `clicked` → `window.on_drum_part_button_clicked`; `Gtk.EventControllerKey` → `_on_instrument_button_key_pressed`; `Gtk.GestureClick` (BUTTON_SECONDARY) → context menu; `Gtk.DragSource` (MOVE) + `Gtk.DropTarget` (FileList, COPY) | one per part; label truncated to 11 chars with `…` |
| `Gtk.Box` button_container | *repeater* | (+ `new-drum-placeholder` on the placeholder) | — | button + hexpanding `Gtk.Label` spacer |
| `Gtk.Label` spacer | *repeater* | — | — | hexpand filler |
| `Gtk.DragIcon` + `Gtk.Label` | 1 per drag | — | — | drag icon shows the button label |

Repeaters: 10 default parts × (`beats_per_page` 16 or 8) toggles × ≥2 pages,
grown on demand. `reset_carousel_pages` keeps
`max(2, active_pages + 1, current_page + 2)` pages.

Keyboard navigation, all of it in this file and all of it part of the
component's identity: Right at the end of a page scrolls to the next page and
focuses its leftmost toggle; Left at the start of a page scrolls back and
focuses the rightmost toggle, or, on page 0, focuses the instrument button;
Right on an instrument button jumps into the current page's first toggle; the
carousel's own key controller swallows Left/Right so it never page-navigates.

Tooltips: _"Click to Preview {name}"_, `Missing file: {path}`,
`Temporary part: {name} (MIDI Note {n})`.
Rebuild entry points: `rebuild_carousel(focus_beat_index:)`,
`rebuild_drum_parts_column`, `add_drum_part`, `update_drum_button`,
`update_drum_parts_spacing(is_compact:)`. The post-rebuild scroll is a
`GLib.timeout_add(50, …)` — a real timing dependency, not incidental.

## 9. `src/ui/drum_grid_builder.py` → `_show_drum_part_context_menu` — drum-part popover menu

Target: `lib/drum_machine/drum_part_menu.rb` — **exists**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` | 1 | — | `popup` / `popdown` | parented on the instrument button |
| `Gtk.Box` | 1 | — | — | vertical, spacing 0 |
| `Gtk.Button` | 4 | `flat` | `clicked` | see table |
| `Gtk.Separator` | 1 | — | — | before "MIDI Mapping" |

| Item | Enabled | Tooltip | Action |
|---|---|---|---|
| _"Preview"_ | always | — | `preview_drum_part` |
| _"Replace…"_ | always | _"Replace with new sound"_ | file chooser _"Select New Sound"_ |
| _"Remove"_ | only when >1 part remains | _"At least one drum part must remain"_ when disabled | `remove_drum_part`; toasts _"Removed drum part: {}"_ / _"Failed to remove drum part"_ |
| _"MIDI Mapping"_ | always | _"Configure MIDI note for export"_ | `MidiMappingDialog`; toast _"MIDI note updated"_ |

## 10. `src/ui/drum_grid_builder.py` → `create_new_drum_placeholder` — drag-and-drop placeholder

Target: `lib/drum_machine/drum_grid.rb` (same file) — **exists**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Revealer` | 1 | — | — | SLIDE_DOWN, 100ms in / 50ms out, then removed on a `GLib.timeout_add(50, …)` |
| `Gtk.Box` + `Gtk.Button` | 1 | `new-drum-placeholder`, + `highlight`; button `drum-part-button`, `flat` | — | label `+ New`, tooltip `Drop audio files here to add new drum` (both untranslated upstream) |

This is the app's only empty/affordance state: it appears while a file drag is
over the window and disappears on leave or drop.

## 11. `src/dialogs/midi_mapping_dialog.py` — MIDI mapping dialog

Target: `lib/drum_machine/midi_mapping_dialog.rb` — **exists**. Code-built,
no blueprint.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | — | title _"MIDI Mapping"_, content-width 450 |
| `Adw.ToolbarView` | 1 | — | — | top header bar + bottom button box |
| `Adw.HeaderBar` | 1 | — | — | `show-title: true` |
| `Gtk.ScrolledWindow` | 1 | — | — | policy NEVER/AUTOMATIC, propagate natural height |
| `Gtk.Box` content_box | 1 | — | — | vertical, spacing 24, 24px side margins |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | _"Note Assignment"_ (description _"Assign a MIDI note for '{}'. This ensures correct playback when exporting."_), _"Standard Instruments"_ (description _"Select a General MIDI instrument to automatically set the note."_) |
| `Adw.ActionRow` | 2 | — | — | _"MIDI Note"_ (subtitle = GM name or _"Custom Note"_), _"Instrument Preset"_ |
| `Gtk.SpinButton` | 1 | — | `value-changed` → `_on_value_changed` | 0–127, step 1, page 12, initial `midi_note_id or 36`, valign center |
| `Gtk.DropDown` | 1 | — | `notify::selected` → `_on_preset_selected` | `Gtk.StringList` of 47 GM percussion entries `"{note} - {name}"`, `enable_search`, `INVALID_LIST_POSITION` for a custom note |
| `Gtk.Box` button_box | 1 | — | — | vertical, spacing 12, halign center, margin-bottom 32 |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → `_on_save_clicked` | _"Save"_ |

`GM_PERCUSSION_MAP` is 47 translated instrument names, notes 35–81. All 47 are
translatable strings the port must carry.

## 12. `src/dialogs/audio_export_dialog.py` + `src/gtk/audio-export-dialog.blp` — audio export dialog

Target: `lib/drum_machine/audio_export_dialog.rb` — **exists**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template `AudioExportDialog`) | 1 | — | `closed` → `_on_dialog_closed` (cancels the export) | content-width 450, title _"Export Audio"_ |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | show-title |
| `Adw.Banner` `warning_banner` | 1 | — | — | hidden unless silent parts; title _"Part “{}” is Silent"_ / _"Parts “{}” and “{}” are Silent"_ / _"{} Parts are Silent"_ |
| `Gtk.Overlay` | 1 | — | — | hosts the progress bar |
| `Gtk.ProgressBar` | 1 | `osd` | pulsed from a background thread | valign start, hidden until export starts |
| `Gtk.ScrolledWindow` | 1 | — | — | hscrollbar never, propagate natural height |
| `Gtk.Box` content_box | 1 | — | — | vertical, spacing 24, 24px margins |
| `Adw.PreferencesGroup` | 2 | — | — | unnamed export group, and _"Metadata"_ |
| `Adw.ComboRow` `format_row` | 1 | — | `notify::selected` → `_on_format_changed` | _"Audio Format"_; `Gtk.StringList` filled from the registry |
| `Gtk.StringList` `format_list` | 1 | — | — | _"MP3"_, _"FLAC (Lossless)"_, _"Ogg Vorbis"_, _"WAV (Uncompressed)"_ |
| `Adw.SpinRow` `repeat_row` | 1 | — | — | _"Repeat Count"_ / _"How many times to repeat the pattern"_, 1–100, value 5, step 1, page 5 |
| `Adw.EntryRow` | 2 | — | — | _"Artist Name"_ (prefilled with `getpass.getuser()`), _"Song Name"_; `show-apply-button: false` |
| `Adw.ActionRow` `cover_row` | 1 | — | — | _"Cover Art"_, activatable-widget = cover button |
| `Gtk.Button` `cover_button` | 1 | — | `clicked` → `_on_cover_button_clicked` | _"Choose File…"_, relabelled to the chosen filename truncated to 20 chars + `…` |
| `Gtk.Box` button_box | 1 | — | — | vertical, halign center, spacing 12, margins 24/24/16/32 |
| `Gtk.Button` `export_button` | 1 | `suggested-action`, `pill` | `clicked` → `_on_export_clicked` | _"Export Audio"_ |
| `Gtk.Button` `cancel_button` | 1 | `destructive-action`, `pill` | `clicked` → `_on_cancel_clicked` | _"Cancel Export"_, hidden until export starts; toast _"Export cancelled successfully"_ |
| `Gtk.Box` `status_overlay` | 1 | — | — | vertical, halign center, spacing 6, hidden until export starts |
| `Gtk.Label` `status_label` | 1 | `heading` | — | _"Exporting…"_ |
| `Gtk.Label` `detail_label` | 1 | `caption` | — | _"Processing…"_ |
| `Gtk.Adjustment` | 1 | — | — | type, for the spin row |

Metadata rows go insensitive for WAV (`supports_metadata: false`). During
export: format row, repeat row and metadata insensitive, export button hidden,
cancel button shown. Completion toasts: _"Audio exported to {}"_ (with the
_"Open"_ toast button) or _"Export failed"_.

`ExportMetadata` (second class in the same file) owns the artist/song/cover
rows → fold into the same port file or `lib/drum_machine/export_metadata.rb`.

## 13. `src/utils/export_progress.py` — export progress + background task

Target: `lib/drum_machine/export_progress.rb` — **exists**.

Not a widget, but it drives four of the dialog's widgets, so it belongs in the
inventory. `ExportPhase` enum (`preparing`/`rendering`/`saving`) →
label pairs: _"Preparing…"_/_"Initializing…"_, _"Rendering audio…"_/_"Processing
beats…"_, _"Saving file…"_/_"Writing to disk…"_, fallback
_"Exporting…"_/_"Processing…"_. A daemon thread pulses the progress bar every
`PULSE_INTERVAL_SECONDS` (1.0s) via `GLib.idle_add`; `ExportTask` runs the
export on another daemon thread and can kill the ffmpeg subprocess on cancel.
In Ruby this becomes `GLib::Timeout.add` plus a thread whose UI touches go
through `GLib::Idle.add`.

## 14. `src/dialogs/reset_defaults_dialog.py` + `src/gtk/reset-defaults-dialog.blp` — reset confirmation

Target: `lib/drum_machine/reset_defaults_dialog.rb` — **exists**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AlertDialog` | 1 | — | `response::reset` → `_on_reset`, `response::cancel` → `_on_cancel` | heading _"Reset to Defaults?"_; body _"This will clear the current pattern and restore all samples, BPM, and volume to their default values. This action cannot be undone."_; close-response and default-response both `cancel` |

Responses: `cancel` _"_Cancel"_; `reset` _"_Reset"_ **destructive**.
Presents itself in `__init__` — the constructor is the presenter.

## 15. `src/dialogs/save_changes_dialog.py` + `src/gtk/save-changes-dialog.blp` — unsaved-changes confirmation

Target: `lib/drum_machine/save_changes_dialog.rb` — **exists**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AlertDialog` | 1 | — | `response::save` → `_on_save`, `response::discard` → `_on_discard`, `response::cancel` → `_on_cancel` | heading _"Save Changes?"_; body _"Current pattern contains unsaved changes. Changes which are not saved will be permanently lost."_; close-response `cancel`, default-response `save` |

Responses: `cancel` _"_Cancel"_; `discard` _"_Discard"_ **destructive**;
`save` _"_Save"_ **suggested**.

## 16. `src/handlers/file_dialog_handler.py` — file dialogs and pattern loading

Target: `lib/drum_machine/file_dialogs.rb` — **exists**.

Six distinct `Gtk.FileDialog` flows, each with its own filter and title — all
user-facing components:

| Flow | Title | Filter | Notes |
|---|---|---|---|
| Open pattern | _"Open MIDI File"_ | `*.mid` _"MIDI files"_ | modal; unsaved-changes gate first |
| Save pattern | _"Save Sequence"_ | `*.mid` _"MIDI files"_ | initial name `<filename or 'new_sequence'>.mid`; appends `.mid` |
| Add samples | _"Add Audio Samples"_ | `*.wav *.mp3 *.ogg *.flac` _"Audio files"_ | `open_multiple` |
| Replace sound | _"Select New Sound"_ | same audio filter | single |
| Save audio | _"Save Audio File"_ | per-format pattern/name | initial name `<song title or suggested>.<ext>` |
| Cover art | _"Select Cover Art"_ | `*.png *.jpg *.jpeg` _"Image files"_ | single |

Error states: toasts _"Failed to open file"_, _"Failed to load pattern"_;
cancellation is a logged `GLib.Error` and nothing else. Also owns
`setup_pattern_menu` (§5) and `self.filename`, the basename reused as the
export suggestion.

## 17. `src/handlers/drag_drop_handler.py` — drag and drop

Target: `lib/drum_machine/drag_drop.rb` — **exists**.

| Controller | On | CSS it toggles | Signals |
|---|---|---|---|
| `Gtk.DropTarget` (`Gdk.FileList`, COPY) | the window | `drag-hover` on the window; shows/hides the `+ New` placeholder | `drop`, `enter`, `leave` |
| `Gtk.DropTarget` (`Gdk.FileList`, COPY) | each instrument button | `drag-over-replace` | `drop`, `enter`, `leave` |
| `Gtk.DragSource` (MOVE) | each instrument button | `drag-source-active` | `prepare`, `drag-begin`, `drag-end` |
| `Gtk.DropTarget` (string, MOVE) | the drum-parts column | `insert-above` / `insert-below` on the hovered row | `drop`, `motion`, `leave` |

Validation and its toasts: _"Not a supported audio file"_, _"File not found"_,
_"Selected item is not a file"_, _"File too large: {:.1f}MB (max 50MB)"_,
_"No valid audio files found"_, _"Error processing file: {}"_, _"Sound replaced"_,
_"Failed to replace sound"_, and the multi-file summaries _"Added {} drum
part, {} files skipped"_, _"Added {} drum parts, {} files skipped"_,
_"Added {} drum parts"_, _"{} files skipped"_.

Reorder insertion index is computed from the pointer `y` against each child's
allocation centre — the insertion line is pure CSS box-shadow (§20).

## 18. `src/services/ui_helper.py` — playhead and pattern-to-UI bridge

Target: `lib/drum_machine/ui_helper.rb` — **exists**.

Adds/removes `toggle-active` on a whole vertical column of toggles for the
playing beat, deactivates every rendered toggle, pushes a loaded pattern into
the toggles, sets the BPM spin value, and forwards carousel scrolls. Reaches
the toggles by `getattr(window, "<part_id>_toggle_<n>")` — the port needs a
real lookup table instead.

## 19. `src/services/drum_machine_service.py` + `save_changes_service.py` — playback and dirty state

Targets: `lib/drum_machine/drum_machine_service.rb`,
`lib/drum_machine/save_changes_service.rb` — **exists**.

Not widgets, but they own `beats_per_page`, `active_pages`, `playing_beat` and
the unsaved-changes flag that three dialogs and five actions read. The playback
loop runs on its own thread and highlights the playhead through `ui_helper`.
`prompt_save_changes(on_save:, on_discard:)` is what raises §15.

## 20. `src/style.css` + `src/style-dark.css` — stylesheets

Target: `lib/drum_machine/style.rb` (two `Gtk::CssProvider`s, light + dark) —
**exists**. Note: neither stylesheet is loaded anywhere in upstream's Python —
they are only listed in the GResource manifest (blocker 9).

Classes defined: `adw-window` (background `#D38CFF` light / `#6b369c` dark),
`drum-machine-box`, `drum-toggle`, `toggle-active`, `drum-machine-box.medium`,
`drum-machine-box.compact`, `drum-part-button`, `bottom-wrapper`, `disabled`,
`drag-over-replace`, `new-drum-placeholder`, `new-drum-placeholder.highlight`,
`export-button`, `drag-source-active`, `insert-above`, `insert-below`, plus a
`box:drop(active)` reset. `half-view` is applied by a breakpoint but **defined
in neither stylesheet** — it is read only from Python.

## 21. Data, resources and translations

| Upstream | Target | Notes |
|---|---|---|
| `src/drum-machine.gresource.xml` | — | two stylesheets, `window.ui`, four dialog `.ui`s, and `share-symbolic.svg` under `/icons/scalable/actions/`. The Ruby port builds widgets in code, so only the icon needs a resource path (or an `icon_theme.add_search_path`). |
| `data/icons/hicolor/scalable/actions/share-symbolic.svg` | keep as data | the export button's icon; not a stock name |
| `data/icons/.../io.github.revisto.drum-machine*.svg` | keep as data | app icon, Devel variant, symbolic, Source |
| `data/drumkit/*.wav` (10) | keep as data | kick, kick-2, kick-3, snare, snare-2, hihat, hihat-2, clap, tom, crash |
| `data/patterns/*.mid` (6) | keep as data | the `DEFAULT_PATTERNS` entries |
| `data/io.github.revisto.drum-machine.gschema.xml` | — | **empty schema, no keys** — nothing to port, and no preferences dialog exists |
| `data/io.github.revisto.drum-machine.desktop.in`, `.metainfo.xml.in` | port metadata | translated via `po/` |
| `po/` — 28 locales + `drum-machine.pot` | translation-parity step | `POTFILES.in` lists 17 files |
| `src/config/constants.py` | `lib/drum_machine/constants.rb` | `NUM_TOGGLES 16`, `GROUP_TOGGLE_COUNT 4`, `DEFAULT_BPM 120`, `DEFAULT_VOLUME 100`, `MIXER_CHANNELS 32`, `PULSE_INTERVAL_SECONDS 1.0`, the 10 default part names and 6 pattern names (all translated), supported input formats |
| `src/config/export_formats.py` | `lib/drum_machine/export_formats.rb` | the four-format registry and its display strings |
| `src/models/drum_part.py` | `lib/drum_machine/drum_part.rb` | id/name/file_path/is_custom/midi_note_id |
| `src/utils/name_utils.py` | `lib/drum_machine/name_utils.rb` | `extract_name_from_path`, fallback _"Custom Sound"_ |
| `src/interfaces/player.py`, `src/interfaces/sound.py` | fold into the services | ABCs with no Ruby equivalent |
| `src/services/sound_service.py`, `drum_part_manager.py`, `pattern_service.py`, `audio_export_service.py`, `audio_renderer.py`, `file_encoder.py` | `lib/drum_machine/<same>.rb` | audio/MIDI engine — see blocker 2 |
| `src/services/preset_service.py` | **do not port** | dead code: a second class also named `PatternService`, imported by nothing |
| `src/meson.build`, `src/drum-machine.in`, `Makefile`, `snap/`, `io.github.revisto.drum-machine.json`, `requirements.txt`, `python-dependencies.json`, `.flake8`, `.github/` | **not ported** | Python/meson/flatpak build plumbing; the fork uses Nix + Bundler |

---

## Blockers and decisions needed before writing code

1. **Layout convention.** The pilot port uses flat `lib/<thing>.rb` with
   top-level classes; this fork's skeleton, gemspec and `exe/drum-machine`
   already use `DrumMachine::` under `lib/drum_machine/`. This inventory
   assumes `lib/drum_machine/`. Confirm before the first file lands, because
   changing it later touches every `require_relative`.
2. **Audio and MIDI have no Ruby equivalent of the upstream stack.** Upstream
   depends on `pygame` (mixer, 32 channels, per-sample playback), `numpy`
   (buffer mixing and normalisation in `audio_renderer.py`), `mido` (MIDI read
   and write in `pattern_service.py`) and a shelled-out `ffmpeg` (encoding and
   metadata in `file_encoder.py`). The Ruby port needs a decision on each:
   playback (GStreamer bindings vs. shelling out), WAV decode/mix (pure Ruby
   over `data/drumkit/*.wav` is feasible — all ten are plain WAV), MIDI
   (a pure-Ruby reader/writer, since `midilib` is not in `gemset.nix`), and
   encoding (ffmpeg is already a subprocess upstream, so keep it). Check
   `gemset.nix` / `flake.nix` before assuming any gem is available.
3. **`app.shortcuts` does not exist upstream.** `primary_menu` has a
   _"_Keyboard Shortcuts"_ item pointing at it and `shortcuts-dialog.blp`
   advertises it, but `application.py` only ever installs `app.about`, and
   nothing loads `shortcuts-dialog.ui`. The menu item is dead in the shipping
   app. The port should install the action and present the dialog — i.e. be
   *more* correct than upstream — but that is a deliberate divergence to record.
4. **Action-name mismatch.** The shortcuts dialog names `win.load_pattern` and
   `win.save_pattern` (underscores); the pattern split-button installs
   `win.load-pattern` (hyphen, string parameter). These are two different
   actions and both exist. Reproduce both names.
5. **Toggle lookup by `getattr(window, "<id>_toggle_<n>")`.** Upstream stashes
   every toggle and instrument button as a dynamic attribute on the window, and
   `go_to_instrument` parses the widget *name* to find the part. The port needs
   an explicit registry (e.g. `@toggles[[part_id, beat]]`); decide its shape
   before writing §8, because §7, §18 and §19 all read through it.
6. **Threads.** Playback, the progress pulse and the export worker are all
   Python daemon threads calling `GLib.idle_add`. Confirm the Ruby bindings'
   idle/timeout story (`GLib::Idle.add`, `GLib::Timeout.add`) and that the
   playback thread can be joined on `stop` without deadlocking the main loop.
7. **`Adwaita::ShortcutsDialog` / `ShortcutsSection` / `ShortcutsItem`
   availability.** The pilot port uses them, with the note that the items take
   *positional* arguments despite the error message advertising keywords.
   Verify against the libadwaita pinned in this fork's `flake.lock`.
8. **Bindings to verify before §3 and §17** (the `ruby-gtk` skill is mandatory
   here): `Gtk::ScaleButton`'s `value-changed` signature, `Adw.SplitButton`
   menu-model assignment, `Gdk::FileList` as a `Gtk::DropTarget` type,
   `Gdk::ContentProvider.new_for_value` for the string reorder payload, and
   `notify::css-classes` on a plain `Gtk::Box` — the breakpoint mechanism in §3
   depends entirely on that last one firing.
9. **The stylesheets are never loaded upstream.** `style.css` and
   `style-dark.css` sit in the GResource but no Python code adds a
   `Gtk.CssProvider`, so the shipping app shows default Adwaita colours and the
   purple theme in the screenshots is unreachable. Decide whether the port
   loads them (matching the screenshots and `data/screenshots/*.png`) or
   matches the running binary. Recommend loading them, and recording the
   divergence.
10. **`half-view` is applied but undefined in CSS.** Not a bug to fix — just
    confirm the port's stylesheet does not need a rule for it.

---

## Re-survey against `lib/` (second pass)

Method: `component-identification`'s `component-scan.sh` run over a `git
archive origin/main src` export and over `lib/`, then every differing row read
in the file.

| Axis | Upstream | Port | Gap |
|---|---:|---:|---|
| widget rows | 75 | 72 | none real — see below |
| distinct widget types | 41 | 39 | `Gtk.VolumeButton`, `Gtk.Widget` are type annotations only |
| applied CSS classes | 22 | 25 | no upstream class unapplied in the port |
| CSS classes defined in the stylesheets | 16 | 16 | all 16 present in `style.rb` |
| signals | 23 | 23 | no upstream signal unconnected |
| window actions | 18 + 2 parameterised + 1 app | same | names built in a loop, so the scan's `action` stream under-reports both sides |

Rows that look like gaps and are not:

- `Gtk.VolumeButton` — upstream `window.py:226` only names it in
  `on_volume_changed`'s type hint; the real widget in `window.ui` is
  `GtkScaleButton`, which the port has.
- `Gtk.Widget`, `Gtk.MAJOR/MINOR/MICRO` — type hints and version constants, not
  widgets. The port's equivalents are `Gtk::Version::MAJOR` etc. (there is no
  `Gtk::VERSION`).
- `src/handlers/drag_drop_handler.py` scans 15 widget rows to
  `drag_drop.rb`'s 2; 13 of the 15 are parameter type hints
  (`Gtk.Button`, `Gtk.Box`, `Gtk.Widget`). The two real widgets —
  `Gtk.DragIcon` and its `Gtk.Label` — are both in the port.
- `src/window.py`'s 11 widget rows are all type hints; the window's real tree
  is `src/window.ui`'s 20 rows, which `window.rb` reproduces one for one.
- `src/ui/drum_grid_builder.py`'s 19 rows split in the port as
  `drum_grid.rb` (15) + `drum_part_menu.rb` (4) = 19.
- `Gtk.Overlay` in `audio_export_dialog.rb` is an addition, standing in for the
  blueprint's overlay child nesting.
- `new-drum-placeholder.highlight` is defined in both stylesheets and applied
  by nothing, upstream or port — dead on both sides (see blocker 10's
  neighbour, `half-view`, which is the mirror case: applied, never defined).

### Blockers now resolved

| # | Resolution in the tree |
|---|---|
| 1 | `DrumMachine::` under `lib/drum_machine/` — settled, every file follows it |
| 2 | Pure-Ruby WAV decode/mix in `audio_renderer.rb` + `audio_export_service.rb`; MIDI read/write in `pattern_service.rb`; `ffmpeg` subprocess kept in `file_encoder.rb`; playback in `sound_service.rb` |
| 3 | `app.shortcuts` is installed and `shortcuts_dialog.rb` presents it — the recorded divergence from upstream stands |
| 4 | Both name spellings exist: underscore actions in `window_actions.rb`'s `ACTIONS` table, hyphenated parameterised `load-pattern` / `open-file` alongside |
| 5 | Explicit toggle registry, with `TOGGLE_NAME_SEPARATOR = "_toggle_"` kept for `go_to_instrument`'s name parsing |
| 6 | `GLib::Timeout` / `GLib::Idle` through `drum_machine_service.rb` and `export_progress.rb` |
| 7 | `Adwaita::ShortcutsDialog` / `ShortcutsSection` / `ShortcutsItem` all work; items take **positional** `(title, accelerator)` despite the error text advertising keywords |
| 8 | `Gtk::ScaleButton`, `Adwaita::SplitButton` menu model, `Gdk::FileList` drop target and `notify::css-classes` on a plain `Gtk::Box` all verified by the breakpoint table in `window.rb` |
| 9 | The port loads both stylesheets via `Style.install` — the deliberate, recorded divergence from the shipping binary |
| 10 | No rule needed for `half-view`; it is read from Ruby only |

### What remains for later steps

Component coverage is complete, so the open work is not *component* work:

- **test-parity** — `test/check_pattern_service.rb` and `test/drive_main_window.rb`
  are now wired into `rake drive`/`rake test` (see translation-parity round 2
  addendum below for the rest of this file's history); `spec/` still has only
  `spec_helper.rb` plus the 6-example suite `rake spec`/`rake spec_direct` run.
- **data** — `data/` carries the 10 drumkit WAVs, the 6 `.mid` patterns, the
  app icon, the symbolic app icon and `share-symbolic.svg` (the export
  button's icon). Upstream's `.Devel` and `.Source` icon variants are not in
  the fork's `data/` — cosmetic, not a component.
- **not ported, by decision** — `src/services/preset_service.py` (dead code),
  the empty GSettings schema (no keys), and all meson/flatpak/snap plumbing.

**Addendum (round 2, 2026-11-07):** the two lines this section used to carry —
"`po/` has not been carried over at all" and "`.desktop.in`/`.metainfo.xml.in`
are not ported" — are now false and have been removed rather than left to
mislead a future reader. As of this round: `po/` holds all 28 upstream
locales plus `LINGUAS`/`POTFILES.in`, rewritten to Ruby paths, with `.mo`
files built under `locale/` (see `.reports/translation-parity.md`); and
`data/io.github.revisto.drum-machine.desktop.in` and `...metainfo.xml.in`
are byte-identical to upstream (`diff` empty both ways). Both are closed.
