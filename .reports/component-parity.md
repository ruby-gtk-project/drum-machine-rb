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
| `Adw.ShortcutsItem` | 15 | 15 | — | — | ✓ (value verified live by a drive check) / ✗ (no `action-name` GObject property set on the widget itself) | ✓ | **gap, narrowed**: the widget never carries `action-name` as a property; the value it displays is proven correct by test, not by inspection |

Still a gap because the facet (the property existing on the widget) is
absent, not because the behaviour is wrong — the behaviour is now actively
tested and correct. Downgrading this from "no test catching it" (false
today) to "the property itself is unset" (true today, and low severity) is
itself a finding: a stale parity document would have continued reporting a
closed risk as open.

## New gap found this round: default drum-part and pattern names are untranslated

This is a **text-axis** gap on two units the existing inventory marks
"exists" with no gap noted:

- **Unit 8** (`src/ui/drum_grid_builder.py` → `lib/drum_machine/drum_grid.rb`
  + `drum_part_manager.rb`) — the ten default `drum-part-button` row labels.
- **Unit 5** (`src/window.ui` → `pattern menu` → `lib/drum_machine/pattern_menu.rb`)
  — the six default pattern-menu entries.

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
taken on faith. One non-fatal defect inside the run: step 24's screenshot
(`tmp/shots/06-half-view.png`) throws `RuntimeError: widget produced no
render node (not realised yet?)` and the file is never written, while the
*check* for that step still passes. Cosmetic to the gate's pass/fail number,
real as a drive-script defect (see `test-parity.md`).

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
