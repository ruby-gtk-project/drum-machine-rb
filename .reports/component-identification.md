# Component identification — drum-machine-rb

| | |
|---|---|
| Upstream | `origin/main` @ `fe31c4c` ("Update Hebrew translation") |
| Port | `ruby` @ `cd13b2e` ("Restore the detailed component inventory") |
| Method | `component-identification` skill, Step 1 (declarative `.ui`/`.blp` first), then `component-scan.sh` over both trees (`git worktree add --detach /tmp/dm-upstream origin/main`, `/tmp/dm-port origin/ruby`), cross-checked by reading |

The `ruby` branch already carries a component inventory at
`.reports/component-inventory.md` (21 numbered units + a re-survey pass). That
document is the result of this skill having been run once already, at
`90a3ede`/`cd13b2e`. This pass does not redo it from scratch; it **re-runs the
scan independently** and spot-checks the inventory's specific claims rather
than trusting them.

## Re-run of the scan

```
bash .claude/skills/component-identification/scripts/component-scan.sh /tmp/dm-upstream > /tmp/up.tsv   # 164 rows
bash .claude/skills/component-identification/scripts/component-scan.sh /tmp/dm-port     > /tmp/port.tsv # 147 rows
```

Aggregate counts (raw, pre-reconciliation — see `component-parity.md` for the
per-file union that actually answers "is anything missing"):

| kind | upstream | port |
|---|---:|---:|
| widget | 120 | 95 |
| controller | 23 | 9 |
| type (non-widget GTK class) | 70 | 34 |
| css | 31 | 33 |
| css-name | 0 | 0 |
| signal | 34 | 53 |
| action | 20 | 3 |

Raw totals are not a verdict (the skill is explicit that this is a per-file,
per-unit question, not an app-wide total). The large `action` gap (20 vs 3) and
`controller` gap (23 vs 9) are explained in `component-parity.md`: the
upstream numbers are inflated by `grep`-visible literal occurrences inside a
loop (`drag_drop_handler.py`'s `Gtk.DragSource`/`Gtk.DropTarget` matched 4 and
13 times are one drag source and one drop target built once per instrument
row, not 17 distinct controllers) and by `shortcuts-dialog.blp`'s 15
`action-name` literals, which the port's `ShortcutsDialog` does **not**
reproduce as action-name attachments (see finding below — this one is real,
not a scan artifact).

## Units (confirming the existing inventory's boundaries)

The existing inventory's 21 units match the `.blp`/`.ui` template roots
(`src/window.ui`'s one `<template>`, the three dialog `.blp`s, the standalone
`shortcuts-dialog.blp`) plus the pure-Python units (services, handlers,
models, config) that have no template. I did not find an upstream widget-tree
root the inventory missed: `find /tmp/dm-upstream \( -name '*.blp' -o -name
'*.ui' \)` returns exactly the five files the inventory already maps
(`window.ui`, `audio-export-dialog.blp`, `reset-defaults-dialog.blp`,
`save-changes-dialog.blp`, `shortcuts-dialog.blp`).

## Finding: `ShortcutsDialog` drops the `action-name` facet

`src/gtk/shortcuts-dialog.blp` gives every `Adw.ShortcutsItem` an
`action-name` (`win.clear_toggles`, `win.play_pause`, etc. — 15 of them). The
port's `lib/drum_machine/shortcuts_dialog.rb` builds `ShortcutsItem.new(label,
accelerator)` — **title and accelerator only, no action-name**:

```ruby
def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
```

This is a genuine facet drop (the "Actions" row in the component-identification
table), not a binding limitation recorded anywhere in the port's own ledger.
Functionally the accelerators shown are hand-typed strings in
`SECTIONS`, duplicating — not reading from — the accelerators
`WindowActions`/`Application` actually bind. The two are consistent *today*
(verified by diff against `window_actions.rb` and `application.rb`), but
nothing keeps them consistent: change an accelerator in `WindowActions::ACTIONS`
and the shortcuts dialog goes stale silently, with no test catching it. Not a
functional gap today; a structural one that should be on record. See
`component-parity.md` and `accountability-ensurance.md`.
