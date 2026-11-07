# Translation parity — drum-machine-rb

| | |
|---|---|
| Upstream | `main` @ `fe31c4c` |
| Port | `ruby` @ `adc4970` |
| Domain | `drum-machine` (matches; `lib/drum_machine/translation.rb` binds this exact name) |
| Upstream messages (source, excl. `po/`) | 259 |
| Ported | 259 (round 2; see "Verdict (round 2 update)" below — was 243) |
| Gaps | **0** (round 2; was 16) |
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

## Verdict (round 2 update)

**Closed.** `lib/drum_machine/constants.rb` now `extend`s `DrumMachine::Translatable`
and wraps all 16 `DEFAULT_DRUM_PARTS`/`DEFAULT_PATTERNS` literals in `_()`,
byte-identical to the upstream msgids. Re-running
`.claude/skills/translation-parity/scripts/msgid-census.sh .` shows all 16
now as `single`-kind rows keyed from `constants.rb` (previously absent
entirely, since a bare literal leaves no marker for the scanner to find).
259/259 messages (100%) byte-identical and reachable; 0 gaps. 28/28
languages shipped and wired to the right domain. The two metadata files and
the `po/` plumbing remain solid.

### Prior verdict (round 1, superseded above)

**Not clean.** 243/259 messages (93.8%) byte-identical and reachable; 16/259
(6.2%) — two entire upstream data tables — ported as untranslatable literals.
28/28 languages shipped and wired to the right domain. The two metadata files
and the `po/` plumbing are solid; the gap is narrow, named, and entirely
confined to `constants.rb`.
