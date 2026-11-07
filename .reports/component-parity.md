# Component parity — drum-machine-rb

| | |
|---|---|
| Upstream | `main` @ `fe31c4c` |
| Port | `ruby` @ `cd13b2e` |
| Units with parity | 20 / 21 (see gap below) |

This builds on `.reports/component-inventory.md` (21 units, all four axes
checked per the existing document) and `.reports/component-identification.md`
(this pass's independent re-scan). I spot-verified rather than re-derived
every row, because the existing inventory already did the per-file union work
the skill asks for and shows its reasoning. What follows is what I checked by
hand and what I found that the existing document does not already say.

## Spot checks that held

- **Right-click gesture on a beat toggle** (`src/window.py:272`
  `_on_right_click_released`, type-hinted `Gtk.GestureClick`). The raw scan
  shows this controller present upstream and absent in the port's aggregate
  count, which looked like a miss. Read: `lib/drum_machine/drum_grid.rb:343`
  and `:489` both build `Gtk::GestureClick.new` with `button =
  Gdk::BUTTON_SECONDARY` and call `@window.on_right_click_released(button)`,
  matching `window.rb:365`. **Correspondence, not a gap** — the scan's
  per-occurrence counting just didn't line up 1:1 with the per-file total.
- **Action accelerators**: `quit` (`<primary>q`), `close_window`
  (`<primary>w`), `shortcuts` (`<primary>question`) all match byte-for-byte
  between `src/handlers/window_actions.py` / `src/application.py` and
  `lib/drum_machine/window_actions.rb` / `lib/drum_machine/application.rb`.
- **`app.shortcuts` / shortcuts dialog reachability**: confirmed as a
  deliberate, recorded divergence (upstream installs no such action and loads
  no `.ui` for the blueprint; the port installs the action and presents the
  dialog). This is *more* correct than upstream, and the inventory says so.
- **Blocker resolutions 1–10** (layout convention, audio/MIDI stack, action
  naming, toggle registry, threads, `Adwaita::ShortcutsDialog` bindings,
  breakpoint mechanism, stylesheet loading, `half-view`) — all read against
  the actual files named in the "Blockers now resolved" table and all check
  out: e.g. `lib/drum_machine/style.rb` does call `Gtk::StyleContext.add_...`
  with two `Gtk::CssProvider`s, `drum_machine_service.rb` does use
  `GLib::Timeout`.

## Gap: `ShortcutsDialog` has no `action-name` facet

See `component-identification.md`. Per the `component-parity` skill's own
rule set, a facet (here, the Actions column) either has a located
counterpart or is a gap — "the port does this differently [by hardcoding
strings]" is not itself a counterpart.

| Widget | Up × | Port × | CSS | Signals | Actions | Text | Verdict |
|---|---:|---:|---|---|---|:-:|---|
| `Adw.ShortcutsItem` | 15 | 15 | — | — | ✗ (hard-coded label+accel, no `action-name`) | ✓ | **gap**: action-name facet dropped |

This is a narrow, low-severity gap (the dialog is read-only chrome, and the
two sources of truth agree today), but it is real: nothing enforces the
agreement, and the drive suite's checks 29–30 only assert the dialog
*presents*, not that its listed accelerators match `WindowActions::ACTIONS`.
Recommended fix: either give `ShortcutsItem` the actual action name (if the
Ruby binding supports it — unverified; the `ruby-gtk` skill should be
consulted for this specifically) or derive `SECTIONS`' accelerator strings
from `WindowActions::ACTIONS` / `Application`'s accel table at load time
instead of duplicating them as literals.

## What the drive suite does and does not exercise (this round's gate)

Ran live: `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` →
**46 of 46 checks passed, DRIVE OK**. The claim in this round's gate
(`drive_ok=true`, 46/46, 0 failed) is real and reproduced, not taken on
faith — I executed it myself.

The drive script's 49 `d.step` blocks touch: window build, pattern menu,
primary menu, toggle state, transport (play/pause/stop), BPM, volume
(including mute/unmute), keyboard-driven carousel paging, a toast with a file
action, the half-view breakpoint rebuild, About, Shortcuts, Reset-to-defaults,
Save-changes, MIDI-mapping and Export dialogs, the drum-part context menu, the
drag placeholder, adding/removing a custom sample, and reset-to-defaults.
That is a wide, real cross-section — not a narrow gate dressed up as broad.

**Not exercised by any check, upstream-side components that exist and are
claimed ported:**
- The six `Gtk.FileDialog` flows (`file_dialogs.rb`) — open/save/add-sample
  native dialogs are not drivable headlessly by this harness and the script
  does not attempt them. No check asserts their behaviour (file-type filters,
  the save-changes-then-discard branch inside `window_actions.rb`'s
  `load_pattern`/`save_pattern`, etc.).
- `AudioExportService`/`AudioRenderer`/`FileEncoder`'s actual encode-to-disk
  path for the non-WAV formats (MP3/OGG/FLAC via the `ffmpeg` subprocess) —
  the drive script opens the export dialog (check 37–38) but does not run an
  export to completion for any format.
- Any of the 28 locales — there are none in the port to exercise (see
  `translation-parity.md`).

A component no check exercises is unverified, per this task's own framing,
even where the earlier inventory calls it "exists". These three are recorded
as open, not as failures — the drive script passing does not cover them, and
nothing else in the repo does either.
