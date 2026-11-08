# Component identification — drum-machine-rb

| | |
|---|---|
| Upstream | `origin/main` @ `fe31c4c` ("Update Hebrew translation") |
| Port | `ruby` @ `adc4970` |
| Method | `component-identification` skill: declarative `.ui`/`.blp` first, `component-scan.sh` over both trees, every differing row read by hand |

The tree already carries two documents from earlier rounds:
`.reports/component-inventory.md` (21 numbered units, a second-pass re-survey)
and the previous `.reports/component-identification.md` (a scan re-run plus
one finding about `shortcuts_dialog.rb`). This pass **re-verifies both
against the code as it stands today**, because the previous
`component-identification.md`'s one finding turned out to be stale — see
below — and a document that is itself stale is exactly the thing
`accountability-ensurance` exists to catch.

## Units confirmed

`find /tmp/dm-upstream \( -name '*.blp' -o -name '*.ui' \)` still returns
exactly the five declarative files the inventory maps: `window.ui`,
`audio-export-dialog.blp`, `reset-defaults-dialog.blp`,
`save-changes-dialog.blp`, `shortcuts-dialog.blp`. No upstream widget-tree
root is missing from the existing 21-unit inventory.

Two items the earlier re-survey flagged as open (`.reports/component-inventory.md`,
"What remains for later steps") have since been closed and should no longer
read as open:

- **`po/` has not been carried over at all** — false today. `po/`, `LINGUAS`
  and `POTFILES.in` all exist on `ruby`, rewritten to Ruby paths; see
  `translation-parity.md`.
- **`.desktop.in`/`.metainfo.xml.in` are not ported** — false today. Both
  exist under `data/` and are byte-identical to upstream.

Flagging this because `accountability-ensurance` treats "a document cited as
settled when the underlying state has moved" as the same failure as an
excuse: a reader of the old inventory who stopped at that section would
believe two closed gaps are still open.

## Correcting the previous round's one finding (`shortcuts_dialog.rb`)

The prior `.reports/component-identification.md` reported:

> "the shortcuts dialog goes stale silently, with no test catching it ...
> Functionally the accelerators shown are hand-typed strings in `SECTIONS`,
> duplicating — not reading from — the accelerators `WindowActions`/
> `Application` actually bind."

Reading `lib/drum_machine/shortcuts_dialog.rb` as it exists now (not as that
finding described it) shows this is no longer accurate:

```ruby
SECTIONS = { ... }  # label => "win.foo" / "app.foo" action name, not an accelerator string
...
def accelerator_for(action_name)
  prefix, name = action_name.split(".", 2)
  table = prefix == "app" ? Application::ACTIONS : WindowActions::ACTIONS
  _, _, accelerators = table.find { |entry_name, *| entry_name == name }
  accelerators&.join(" ")
end
```

`SECTIONS` stores the **action name**, and `accelerator_for` looks the
accelerator up live, at dialog-build time, from the same `ACTIONS` tables
`WindowActions`/`Application` actually bind from — it is not a second,
hand-copied string. And there is a live test for exactly the staleness
scenario the old finding worried about:
`test/drive_main_window.rb:185-196`, step "the shortcuts dialog's
accelerators agree with what is actually bound", asserts
`DrumMachine::ShortcutsDialog.new.send(:accelerator_for, action_name) ==
app.app.get_accels_for_action(action_name)` (canonicalised) for every
`SECTIONS` entry. I ran it live this round (`rake drive`) and it passes.

**Closed this round.** The prior draft of this report recorded a narrower
gap here: `Adw.ShortcutsItem` upstream is given `action-name` directly as a
GObject property (`src/gtk/shortcuts-dialog.blp`'s 15 `action-name` lines),
and the port's `item` helper only ever took a pre-resolved accelerator
string, never setting `action-name` on the widget itself.

Per the `ruby-gtk` skill, the binding was checked directly rather than
guessed from memory:

```ruby
item = Adwaita::ShortcutsItem.new("Label", "<ctrl>q")
item.respond_to?(:action_name=)   # => true
```

`Adwaita::ShortcutsItem` does expose `action_name=` (and `action_name`,
`set_action_name`) as a plain setter over the GObject `action-name`
property. `lib/drum_machine/shortcuts_dialog.rb`'s `item` helper now takes
the action name alongside the label and accelerator and sets it:
`Adwaita::ShortcutsItem.new(label, accelerator).tap { |i| i.action_name = action_name }`.
The facet is populated with the same `"win.foo"`/`"app.foo"` string
`SECTIONS` already carries and `accelerator_for` already resolves the
accelerator from, so there is no second, independently-typed value to drift
— both now come from one place. Re-ran `rake drive` live after the change;
the shortcuts-dialog step (including the accelerator-agreement check) still
passes.

## Scan counts (for the record, re-run this round)

```
component-scan.sh /tmp/dm-upstream  → 164 rows
component-scan.sh .                 → 147 rows
```

Consistent with the prior round's numbers; no new widget-tree units found or
lost since the last scan. Per-axis reconciliation is `component-parity.md`'s
job, not this document's.

## This round's addition: the accessible-properties facet

Re-running the widget-type-count diff (upstream vs. port, summed across
files, same scan) to look for genuine gaps behind the scanner's known
over/under-report patterns, every discrepancy traced to a benign cause
(type-annotation false positives, a factory call site the scan cannot
multiply, or an app/menu-popover component that belongs to a different
file in the same unit) — recorded in `component-parity.md` rather than
repeated here, since each one is a parity verdict, not a new unit.

One genuine miss, caught only because the component-identification table
at the top of this document says to record CSS classes and signals as part
of a widget's identity but says nothing about GtkBuilder's
`<accessibility>` block — a fifth facet this skill's own table omits.
`component-inventory.md` had already transcribed these blocks as plain
prose notes on 4 widgets (`file_pattern_button`, `menu_button`,
`export_audio_button`, the BPM spin button) without flagging them as a
checkable facet, and no later round turned that note into a parity check
until this one. See `component-parity.md`'s new section and
`translation-parity.md`'s "Round 3" section for the finding: all 4 are
unported. Recording the process gap here too — a widget's accessible
name/description is as much part of its identity as its CSS classes, and
should be scanned for and reconciled the same way on every future round of
this skill.

## Round 5: the facet above is closed — this document was one commit stale

This file (last touched at `ab1b8d0`) still described the accessible-name/
description facet as "unported" above. The very next commit on this branch,
`c5697b1`, fixed it: `lib/drum_machine/window.rb`'s `accessible_widget`
helper now builds each of the four widgets from a one-object
`Gtk::Builder` XML fragment carrying a real `<accessibility>` block, sourced
from the same `p_("accessibility", ...)`/`_(...)` strings. Read directly
against `HEAD` this round, not taken on another report's word — confirmed
present at `lib/drum_machine/window.rb:499-512` and exercised by a passing
`rake drive` (47/47) and `rake spec_direct` (6/6) run this round. The
accessible-properties facet is now part of this file's standing widget-
identity checklist (type, CSS, signals, actions, owner, **accessibility
label/description**) for any future round. See `accountability-ensurance.md`'s
"Round 5" for the same staleness named as a process failure.
