# Component parity — drum-machine-rb

| | |
|---|---|
| Upstream | `main` @ `fe31c4c` |
| Port | `ruby` @ `adc4970` |
| Units with parity | 19 / 21 (two gaps below; see also unexercised units at the end) |

This builds on `.reports/component-inventory.md` (21 units) and
`.reports/component-identification.md` (this round's re-check, including a
correction of the previous round's `shortcuts_dialog.rb` finding). What
follows is what changed or what I found that those documents do not already
say.

## Correction carried over from `component-identification.md`

The previous round's component-parity.md reported `Adw.ShortcutsItem` as a
gap on the grounds that `SECTIONS`' accelerators were hand-typed strings
duplicating, and liable to drift from, `WindowActions::ACTIONS` — "nothing
enforces the agreement". Reading the current `shortcuts_dialog.rb`, that is
no longer true: `SECTIONS` stores the action name, and `accelerator_for`
resolves the displayed accelerator live from `WindowActions::ACTIONS` /
`Application::ACTIONS` at dialog-build time. `test/drive_main_window.rb`
step 31 (`the shortcuts dialog's accelerators agree with what is actually
bound`) asserts this for all 15 items and passes — I ran it this round.

| Widget | Up × | Port × | CSS | Signals | Actions | Text | Verdict |
|---|---:|---:|---:|---|---|:-:|---|
| `Adw.ShortcutsItem` | 15 | 15 | — | — | ✓ (value verified live by a drive check; `action-name` GObject property now set via the binding's `action_name=` setter) | ✓ | **closed this round** — see `component-identification.md` |

**Closed this round.** The Ruby binding was checked directly (per the
`ruby-gtk` skill) rather than assumed from the earlier draft's "does not
appear to expose" hedge: `Adwaita::ShortcutsItem` does expose `action_name=`
over the `action-name` GObject property. `shortcuts_dialog.rb`'s `item`
helper now sets it from the same action name `SECTIONS` already carries and
`accelerator_for` already resolves the accelerator from, so the facet and
the value both come from one place. Re-ran `rake drive` live after the
change; the shortcuts-dialog step and its accelerator-agreement check still
pass. See `component-identification.md` for the exact gir check run.

## Gap found in a prior round, closed this round: default drum-part and pattern names are untranslated

This was a **text-axis** gap on two units the existing inventory marks
"exists" with no gap noted:

- **Unit 8** (`src/ui/drum_grid_builder.py` → `lib/drum_machine/drum_grid.rb`
  + `drum_part_manager.rb`) — the ten default `drum-part-button` row labels.
- **Unit 5** (`src/window.ui` → `pattern menu` → `lib/drum_machine/pattern_menu.rb`)
  — the six default pattern-menu entries.

**Closed this round** — see `.reports/translation-parity.md`'s "Verdict
(round 2 update)": `lib/drum_machine/constants.rb` now wraps all 16
`DEFAULT_DRUM_PARTS`/`DEFAULT_PATTERNS` literals in `_()`.

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Button` instrument button (unit 8) | 10 (default set) | 10 | ✓ | ✓ | ✗ — labels sourced from `Constants::DEFAULT_DRUM_PARTS`, 10 bare string literals, `_()` dropped | **gap** |
| pattern-menu item (unit 5) | 6 (default set) | 6 | — | ✓ `activated` | ✗ — labels sourced from `Constants::DEFAULT_PATTERNS`, 6 bare string literals, `_()` dropped | **gap** |

Widget count, CSS and signal wiring are all correct (confirmed by the drive
suite's checks around part add/remove and the pattern menu) — only the text
axis fails, and only for these 16 strings. Full detail, byte-identical
English and port sites: `translation-parity.md`. Recorded here too per that
skill's rule that a text-axis gap belongs in both ledgers.

## Re-ran this round's gate

```
nix develop --command xvfb-run -a rake drive
...
47 of 47 checks passed
DRIVE OK
```

Matches the stated runtime gate (47/47, 0 failed) — reproduced live, not
taken on faith. **Fixed this round:** step 24's screenshot
(`tmp/shots/06-half-view.png`) used to intermittently throw `RuntimeError:
widget produced no render node (not realised yet?)` right after the
breakpoint-triggered rebuild, leaving the file unwritten even though the
*check* for that step passed. `test/gtk_driver.rb`'s `render` now retries up
to 3 extra times, pumping `GLib::MainContext.default.iteration(false)`
between attempts to let the widget finish laying out, before raising. Ran
`rake drive` three times in a row live after the change; `06-half-view.png`
was written every time.

## Units no check exercises — unverified, not done

Per this round's framing ("a component no check exercises is unverified, not
done"), restating and re-confirming the previous round's three items, plus
one addition found this round:

1. **The six `Gtk.FileDialog` flows** (`file_dialogs.rb`) — native file
   pickers are not drivable by this headless harness; no check asserts
   filter lists, the save-changes-then-discard branch, or cancel handling.
2. **Non-WAV export** (MP3/OGG/FLAC via the `ffmpeg` subprocess in
   `file_encoder.rb`) — the drive script opens the export dialog (checks
   38–39) but never runs an export to completion in any format, WAV
   included. `check_pattern_service.rb` does verify the WAV encoder's RIFF
   header in isolation, which is real coverage of that one format's writer,
   but not of the dialog-to-disk path or the other three formats.
3. **Any of the 28 shipped locales** — there is nothing in the port's test
   surface that loads the app under a non-English `LANGUAGE=`/`LC_ALL=` and
   asserts a translated string appears on screen. `translation-parity.md`
   notes this as an unrun check as well; recorded here because it is also a
   component-behaviour claim ("the UI speaks 28 languages") with zero live
   verification.
4. **New this round** — the MIDI-mapping dialog's actual MIDI-note
   reassignment and the drag-and-drop reorder/insert paths in
   `drag_drop.rb` are opened/shown by the drive script (checks 36–37, 42–43)
   but the *effect* of reassigning a note or completing a drop is not
   asserted anywhere; only that the dialog/placeholder appears.

None of these four is reported as a failure — each is a real absence of
verification on a component the earlier inventory lists as built. Treat them
as the next four items in line for the `test-parity` backlog, not as
disproof of the "exists" claim in `component-inventory.md`, which is about
construction, not behavioural proof.
