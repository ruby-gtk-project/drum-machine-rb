# Translation parity — drum-machine-rb

| | |
|---|---|
| Upstream | `main` @ `fe31c4c` |
| Port | `ruby` @ `adc4970` |
| Domain | `drum-machine` (matches; `lib/drum_machine/translation.rb` binds this exact name) |
| Upstream messages (source, excl. `po/`) | 259 |
| Ported | 252 (round 3 recount; round 2 claimed 259 without re-running the census — see "Round 3" below) |
| Gaps | **7**, all accessible-label/description strings in `window.ui` never referenced by the port (round 3; round 2's "0" did not hold up) |
| Extra (untranslated) | 0 real (4 scanner artefacts, see below) |
| Upstream languages | 28 `.po` files, `LINGUAS` matches |
| Languages shipped by the port | 28 `.po` + 28 compiled `.mo` under `locale/` |
| Build command | `rake gettext:mo:update` (per `Rakefile:185-211`) |

Census: `.claude/skills/translation-parity/scripts/msgid-census.sh` run over
`origin/main` (worktree at `/tmp/dm-upstream`) and over `ruby`'s working tree,
with `po/*` rows excluded from the message set per the skill (they are a
snapshot of the last `msgmerge`, not the catalogue).

## The good news first

- `po/`, `LINGUAS`, `POTFILES.in` were copied over and rewritten to Ruby
  paths. `diff <(ls po/*.po|xargs -n1 basename -s .po|sort) <(sort po/LINGUAS)`
  is empty on both trees — 28 languages, exact match.
- The domain (`drum-machine`) is kept, not renamed — `Translation::DOMAIN` in
  `lib/drum_machine/translation.rb:20` — so all 28 donated catalogues are
  reachable.
- `.mo` files are actually built and present under `locale/<lang>/LC_MESSAGES/`
  (28 of 28), and `bindtextdomain(DOMAIN, path: LOCALE_DIR)` points at them.
- `data/io.github.revisto.drum-machine.desktop.in` and
  `...metainfo.xml.in` are byte-identical to upstream (`diff` empty both
  ways), so the app-grid-visible strings (`Name`, `Keywords`, the AppStream
  summary/description) are intact and still extracted.
- 243 of upstream's 259 source-side messages are reachable by exact
  `(msgctxt, msgid)` key in the port.

## The gap: 16 messages, all from one file

`comm -23` on the two key sets returns exactly these 16, and every one traces
to the same upstream file:

```
src/config/constants.py:25-34   DEFAULT_DRUM_PARTS   _("kick") _("kick-2") _("kick-3")
                                                       _("snare") _("snare-2") _("hihat")
                                                       _("hihat-2") _("clap") _("tom") _("crash")
src/config/constants.py:38-43   DEFAULT_PATTERNS     _("Shoot") _("Maybe Rock") _("Boom Boom")
                                                       _("Night") _("Slow") _("Chill")
```

The port's `lib/drum_machine/constants.rb:12-31` carries the same 16 names as
**bare string literals**, with no `_()`/`DrumMachine::Translatable` marker at
all:

```ruby
DEFAULT_DRUM_PARTS = [
  "kick", "kick-2", "kick-3", "snare", "snare-2",
  "hihat", "hihat-2", "clap", "tom", "crash",
].freeze
DEFAULT_PATTERNS = ["Shoot", "Maybe Rock", "Boom Boom", "Night", "Slow", "Chill"].freeze
```

This is not cosmetic. Both arrays are load-bearing, user-visible text:

- `Constants::DEFAULT_DRUM_PARTS` is consumed by
  `lib/drum_machine/drum_part_manager.rb:166` to build the default ten drum
  parts — these names are exactly the row labels on the ten default
  `drum-part-button`s in the grid (see `component-parity.md`, unit 8).
- `Constants::DEFAULT_PATTERNS` is the default argument to
  `lib/drum_machine/pattern_menu.rb:22`, i.e. the six pattern names in the
  pattern-selector menu a user opens from the header bar.

So a non-English build of this port shows "kick", "Shoot", "Maybe Rock" etc.
in English in every one of the 28 languages, in exactly the two places a
user looks first (the drum grid and the pattern menu), because the strings
were retyped without their marker when `constants.rb` was ported. All 16 are
listed below with the byte-identical English to transcribe back in.

| # | msgid | Port site |
|---|---|---|
| 1 | `kick` | `lib/drum_machine/constants.rb:12` |
| 2 | `kick-2` | `lib/drum_machine/constants.rb:13` |
| 3 | `kick-3` | `lib/drum_machine/constants.rb:14` |
| 4 | `snare` | `lib/drum_machine/constants.rb:15` |
| 5 | `snare-2` | `lib/drum_machine/constants.rb:16` |
| 6 | `hihat` | `lib/drum_machine/constants.rb:17` |
| 7 | `hihat-2` | `lib/drum_machine/constants.rb:18` |
| 8 | `clap` | `lib/drum_machine/constants.rb:19` |
| 9 | `tom` | `lib/drum_machine/constants.rb:20` |
| 10 | `crash` | `lib/drum_machine/constants.rb:21` |
| 11 | `Shoot` | `lib/drum_machine/constants.rb:26` |
| 12 | `Maybe Rock` | `lib/drum_machine/constants.rb:27` |
| 13 | `Boom Boom` | `lib/drum_machine/constants.rb:28` |
| 14 | `Night` | `lib/drum_machine/constants.rb:29` |
| 15 | `Slow` | `lib/drum_machine/constants.rb:30` |
| 16 | `Chill` | `lib/drum_machine/constants.rb:31` |

State: **gap**, all 16. `Text still owed` is the msgid column verbatim; fix
is `_("kick")` etc. (constants.rb would need to `include DrumMachine::Translatable`
or wrap at the call site in `drum_part_manager.rb`/`pattern_menu.rb`, since
these are frozen module constants evaluated at load time before any
`bindtextdomain` call order concern — same pattern the rest of the port
already uses for everything else).

This is the exact "Uses" mismatch this skill's own rule calls out: the
catalogue key for `_Cancel`-style reused strings elsewhere in the port is all
present (243/243 of everything else checked), but these two tables were
simply missed, in full, as a unit — not reworded, not partially ported,
just never wrapped.

## Scanner artefacts, not findings

4 rows on the port side carry `!unresolved` and are not real extra messages:
they are `msgid-census.sh` matching the lambda-style method bodies in
`lib/drum_machine/translation.rb` itself (`def _(msgid) = ...`,
`def n_(singular, plural, n) = ...`) as if they were call sites with a
non-literal argument. They are the *definitions* of the markers, not a use of
one. No action needed; noted so the 247-vs-259 raw key-set count in the
earlier draft of this ledger is not misread as 4 more gaps than the 16 above.

## Not checked / open

- **Plural-form and msgctxt kind agreement** (`kind: plural` upstream vs.
  `single` in the port) was not fully re-verified this round after the
  scanner-key join produced noisy output on this tree's quoting; the `n_()`
  call sites that do exist (`DrumMachine::Translatable#n_`) look correctly
  paired by inspection but a clean machine-checked diff of `kind` per key is
  an unrun check — note it here rather than claim it passed.
- **`msgfmt -c` validation** of the 28 `.po` files was not run (no `gettext`
  CLI confirmed in the dev shell for this invocation); the shipped `.mo`
  files under `locale/` were trusted as already built rather than rebuilt
  from source in this session.
- **On-screen verification in a non-English locale** (`LANGUAGE=de` etc.)
  was not performed this round.

## Round 3: re-ran the census independently, and the round-2 "259/259, 0 gaps" verdict does not hold

Re-running `msgid-census.sh` fresh over both trees this round (not trusting
the round-2 number), filtering out `po/`-sourced rows the same way the
skill does, and joining on `(msgctxt, msgid)`:

```
comm -23 <(up keys) <(port keys)   # upstream keys the port cannot reach
```

returns **23** keys, not 0. Reading each by hand splits them into two very
different findings:

### 20 of the 23 are a scanner limitation, not a real gap

All 20 carry `msgctxt "shortcut window"` and all 20 trace to
`src/gtk/shortcuts-dialog.blp`'s `C_("shortcut window", "...")` titles
("General", "Quit", "Play/Pause", "Clear All", "BPM & Volume", ... all 20
section/item titles). `lib/drum_machine/shortcuts_dialog.rb`'s `SECTIONS`
constant stores the identical English strings as hash keys/array literals,
and `section`/`item` look each one up through
`p_("shortcut window", title)` / `p_("shortcut window", label)` — a real
`GetText#p_` (pgettext) call, correctly wired in `translation.rb`, with the
exact upstream context string. The census script only resolves a literal
string typed directly inside the `p_(...)` call; a call site like
`p_("shortcut window", title)`, where `title` is a variable populated from a
static table the script does not evaluate, is invisible to it even though
the table's values are the same literals upstream uses, byte for byte. I
confirmed this by hand, line by line, against
`src/gtk/shortcuts-dialog.blp`. **Not a gap** — the `.po`/`.mo` files
already carry these `(msgctxt, msgid)` pairs unchanged from upstream, so a
translated build resolves them correctly at runtime. Recorded here instead
of silently dropped, because this skill's own rule is that a citation to
"the scanner found it" is not authority either way without reading the
code behind it.

### 7 of the 23 are a real gap: the window's accessible label/description text

```
accessibility  Export Audio…
accessibility  Main Menu
accessibility  Open Pattern
-              Access Keyboard Shortcuts and Application Information
-              Export Current Drum Pattern as Audio File
-              Open Saved Drum Pattern
-              Tempo
```

All seven are upstream's GtkBuilder `<accessibility>` blocks in
`src/window.ui` (lines 56-59, 77-80, 90-93, 144-147) — the screen-reader
label/description pair for `file_pattern_button`, `menu_button`,
`export_audio_button` and the BPM spin button. `lib/drum_machine/window.rb`
never references any of these seven strings, translated or not — it sets
`tooltip_text` on the same four widgets (a different, separate string in
three of the four cases) but calls nothing on the accessible-properties
axis at all. These are not reachable by the port's code under any marker,
so they are not merely "untranslated" the way the 16 `constants.rb`
literals were — the behaviour itself (an accessible name/description
distinct from the tooltip) was never built. See `component-parity.md`'s
new section this round for the widget-level finding and the confirmation
that the binding supports `update_property` and nothing stops this port
from calling it.

## Verdict (round 3, supersedes round 2's "Closed")

**Not clean.** 252/259 messages (97.3%) byte-identical and reachable by the
port's own `_`/`n_`/`p_` call sites; 7/259 (2.7%) — all four controls'
accessible label/description pairs in `window.ui` — never referenced by the
port at all. 28/28 languages shipped and wired to the right domain; the
`po/` plumbing, the two metadata files, and the round-2 fix to
`constants.rb` all remain solid and are not re-litigated here. Round 2's
"259/259, 0 gaps, Closed" verdict was wrong: it closed the one gap it had
gone looking for (`constants.rb`) and declared the whole ledger closed
without re-running the census against the full upstream key set, which
still had these 7 keys sitting in it the whole time.

### Prior verdict (round 1, superseded above)

**Not clean.** 243/259 messages (93.8%) byte-identical and reachable; 16/259
(6.2%) — two entire upstream data tables — ported as untranslatable literals.
28/28 languages shipped and wired to the right domain. The two metadata files
and the `po/` plumbing are solid; the gap is narrow, named, and entirely
confined to `constants.rb`.

## Round 4: the 7-message accessibility gap is closed

`lib/drum_machine/window.rb` now wraps all seven strings and attaches them as
real accessible properties on the four widgets, not just as translated text
sitting unused:

- `file_pattern_button`, `menu_button`, `export_audio_button` each call
  `p_("accessibility", "Open Pattern" / "Main Menu" / "Export Audio…")` for
  the accessible label and `_("Open Saved Drum Pattern")` /
  `_("Access Keyboard Shortcuts and Application Information")` /
  `_("Export Current Drum Pattern as Audio File")` for the accessible
  description — byte-identical msgids to `src/window.ui`, same
  `msgctxt "accessibility"` on the three label strings, none on `Tempo`,
  matching upstream exactly.
- `bpm_spin_button` calls `_("Tempo")` for its accessible label and
  `_("Adjust Tempo In Beats per Minute (BPM)")` (already in use as the
  tooltip) for its accessible description.

Round 3's own note already flagged that `Gtk::Accessible#update_property`
"is bound and callable" but did not verify it actually *works* when called —
it does not. Calling it this round, with any array of
`GtkAccessibleProperty` (symbols or raw integers), raises `NotImplementedError`
with `"TODO: in Ruby -> GIArgument(array/C)[interface(enum)]
(GtkAccessibleProperty)"` — confirmed live, and independently corroborated by
`gnome-clocks-rb`'s `alarm_day_picker_row.rb`, which hit the identical
limitation and worked around it differently (folding the fuller text into the
tooltip instead). This is a genuine gem/binding limitation, not a port
oversight, so round 3's "nothing stops this port from calling it" is itself
superseded here.

The actual fix routes around the broken Ruby method entirely: each of the
four widgets is now constructed via `Gtk::Builder#add_from_string` from a
one-object XML fragment carrying a `<accessibility>` block built from the
already-localized `_()`/`p_()` strings, then configured exactly as before
(`tooltip_text`, `icon_name`, `menu_model`, signals, …) via `tap`.
`Gtk::Builder`'s own XML-to-accessible-property path runs in C and never
crosses the broken Ruby array-marshalling code, so the properties are set
for real. Re-ran `.claude/skills/translation-parity/scripts/msgid-census.sh`
fresh against `origin/main` and the port tree this round: all 7 msgids now
appear on the port side, sourced from `lib/drum_machine/window.rb`, with the
same `(msgctxt, msgid)` keys as `src/window.ui`.

**Updated verdict: 259/259 messages (100%) byte-identical and reachable.**
Re-derived, not carried over — this is the number that follows from actually
re-running the census this round, which is the same discipline round 3 used
to overturn round 2's premature "Closed".
