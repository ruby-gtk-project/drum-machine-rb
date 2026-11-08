# Component parity — drum-machine-rb

| | |
|---|---|
| Upstream | `main` @ `fe31c4c` |
| Port | `ruby` @ `adc4970`, re-audited at `HEAD` (`2b7e413`) |
| Units with parity | 19 / 21; the accessibility-axis gap found on 4 of those "closed" units earlier this round (below) is fixed as of this update |

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

## New gap this round: the accessible name/description axis is entirely unported

`component-inventory.md` already records, as plain notes on units it marks
"exists" with no gap, that four upstream controls carry a GtkBuilder
`<accessibility>` block — a screen-reader-only label/description pair,
separate from the visible tooltip:

```
src/window.ui:56-59   file_pattern_button   a11y label "Open Pattern" (msgctxt "accessibility")
                                             a11y description "Open Saved Drum Pattern"
src/window.ui:77-80   menu_button           a11y label "Main Menu" (msgctxt "accessibility")
                                             a11y description "Access Keyboard Shortcuts and Application Information"
src/window.ui:90-93   export_audio_button   a11y label "Export Audio…" (msgctxt "accessibility")
                                             a11y description "Export Current Drum Pattern as Audio File"
src/window.ui:144-147 bpm_spin_button       a11y label "Tempo"
                                             a11y description "Adjust Tempo In Beats per Minute (BPM)"
```

That note was never followed up into a parity check. Reading
`lib/drum_machine/window.rb` end to end this round: it sets `tooltip_text`
on all four widgets (confirmed, lines 122/129/136/194), and **never calls
anything on the accessible-properties axis at all** — no
`update_property`, no `accessible_role=`, nothing. `grep -n
"accessib" lib/drum_machine/window.rb` returns nothing.

This is not a binding gap. Checked live, per the `ruby-gtk` skill, in the
dev shell under `xvfb-run`:

```ruby
require "gtk4"
Gtk::Widget.ancestors.include?(Gtk::Accessible)   # => true
Gtk::Accessible.instance_methods.grep(/label|description|update_property/i)
# => [:accessible_role, :set_accessible_role, :accessible_role=, :update_property]
```

`update_property` is bound and callable on any `Gtk::Widget`
(`Gtk::Accessible` is in its ancestor chain) — the exact call upstream's
GtkBuilder `<accessibility>` block compiles down to
(`gtk_accessible_update_property(widget, GTK_ACCESSIBLE_PROPERTY_LABEL, ...)`
/ `...DESCRIPTION...`). Nothing stops this port from making the call; it
simply never does.

A screen-reader user of the port hears whatever GTK synthesizes from the
widget's own content/tooltip for these four controls instead of the
deliberately separate, translated label/description text upstream
authored — and for `export_audio_button`, which has no visible label at
all (icon-only), that fallback is weaker still. This also means the four
underlying message-catalogue entries are unreachable English literals the
port's code never references as translatable text at all — see
`translation-parity.md`, which found this independently via the msgid
census and treats it as the same gap on the text axis.

| Widget | Up × | Port × | A11y label | A11y description | Verdict |
|---|---:|---:|:-:|:-:|---|
| `Adw.SplitButton` `file_pattern_button` | 1 | 1 | ✗ | ✗ | **gap** |
| `Gtk.MenuButton` `menu_button` | 1 | 1 | ✗ | ✗ | **gap** |
| `Gtk.Button` `export_audio_button` | 1 | 1 | ✗ | ✗ | **gap** |
| `Gtk.SpinButton` (BPM) | 1 | 1 | ✗ | ✗ | **gap** |

Everything else about these four widgets (type, CSS classes, signal wiring,
visible label/tooltip text) is correct and already covered above or in
`component-inventory.md` — only the accessible-properties facet is missing,
on all four, with no exception.

### Update: fixed this round, and the "not a binding gap" call above was wrong

Calling `update_property` for real — not just checking it is in
`instance_methods` — raises:

```
NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(enum)]
(GtkAccessibleProperty)
```

for every form tried (`[:label, :description]` / integer property codes /
single-element arrays), because the two-array signature's enum array can't
be marshaled by these bindings at all — the failure is before the value
even matters. This is the exact limitation `gnome-clocks-rb`'s
`alarm_day_picker_row.rb` already hit and worked around by folding the
intended accessible text into the tooltip instead; it independently
confirms this is a genuine gem limitation, not something specific to this
app. The previous paragraph's "nothing stops this port from making the
call" was wrong — something does.

The actual fix (in `lib/drum_machine/window.rb`) builds each of the four
widgets from a one-object `Gtk::Builder` XML fragment carrying the
`<accessibility>` block (built from the already-localized `_()`/`p_()`
strings, see `translation-parity.md`'s round 4), then configures the rest
exactly as before via `tap`. `GtkBuilder`'s XML parser sets the accessible
properties in C, never crossing the broken Ruby array-marshalling path, so
this routes around the limitation rather than needing it fixed upstream in
the bindings.

| Widget | A11y label | A11y description | Verdict |
|---|:-:|:-:|---|
| `Adw.SplitButton` `file_pattern_button` | ✓ | ✓ | **parity** |
| `Gtk.MenuButton` `menu_button` | ✓ | ✓ | **parity** |
| `Gtk.Button` `export_audio_button` | ✓ | ✓ | **parity** |
| `Gtk.SpinButton` (BPM) | ✓ | ✓ | **parity** |

Verified: `rake drive` (47/47) and `rake spec_direct` (6/6) both pass with
the four widgets rebuilt this way, and a fresh `msgid-census.sh` run shows
all 7 of the previously-unreachable accessibility msgids now sourced from
`lib/drum_machine/window.rb`.

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
