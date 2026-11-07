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

**What is still a real, narrower gap**, correcting the old finding rather
than repeating it: `Adw.ShortcutsItem` upstream is given `action-name`
directly as a GObject property (`src/gtk/shortcuts-dialog.blp`'s 15
`action-name` lines) — the facet GTK uses to let `Adw.ShortcutsWindow`
cross-reference an item against the app's actual accelerators and (on
platforms where it matters) make the row itself actionable. The port's
`item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)`
takes a pre-resolved accelerator string, never sets `action-name` on the
widget itself. The *value* now matches (proven by the test above); the
*facet* — the widget carrying its own action reference, the way upstream's
does — is still absent. This is a correspondence worth recording, not a
functional regression: there is no evidence `Adw.ShortcutsItem#action-name`
drives any further runtime behavior beyond display in current libadwaita,
and `Adwaita::ShortcutsItem.new` does not appear to expose an `action_name=`
setter in the Ruby binding (not independently re-confirmed against the gir
this round). Recorded for `component-parity.md`'s action axis rather than
re-asserted as the open staleness risk the old report described, because
that risk is specifically what the new test closes.

## Scan counts (for the record, re-run this round)

```
component-scan.sh /tmp/dm-upstream  → 164 rows
component-scan.sh .                 → 147 rows
```

Consistent with the prior round's numbers; no new widget-tree units found or
lost since the last scan. Per-axis reconciliation is `component-parity.md`'s
job, not this document's.
