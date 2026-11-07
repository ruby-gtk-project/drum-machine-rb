# Accountability ensurance — drum-machine-rb

## Scope grepped

`lib/`, `exe/`, `.reports/`, and the repo root for `PORTING.md` (does not
exist on this branch), plus the skill's own `find-excuses.sh` over the whole
tree (excluding `.git`, `po/`, `.claude/skills/`).

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|unimplemented|stub" lib/ exe/
  → (nothing)

bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
  → 7 hits, all inside .reports/component-inventory.md, none in lib/ or exe/
```

## Reading the 7 hits

| Line | Phrase | Verdict label | Read |
|---|---|---|---|
| 472, 486 | "no Ruby equivalent" | "the analogue is the BEHAVIOUR" | Both are the *interfaces* row (`src/interfaces/player.py`, `sound.py` — ABCs with no subclass of their own) and the blocker-2 writeup about `pygame`/`numpy`/`mido`. The actual behaviours (playback, WAV mixing, MIDI read/write) **are** ported — `sound_service.rb`, `audio_renderer.rb`, `pattern_service.rb` exist and their checks pass live (`test/check_pattern_service.rb`, confirmed in `test-parity.md`). The phrase refers only to the abstract-base-class *type*, which Ruby has no equivalent concept for and which carries no behaviour of its own. **Not an excuse** — the behaviour is named, located, and verified running. |
| 475 | "not ported" (×1) + verdict "honest but toothless" | `src/services/preset_service.py` — do not port: dead code, a second class also named `PatternService`, imported by nothing. I verified this independently: `grep -rn "preset_service\|PresetService" /tmp/dm-upstream/src` finds only the file's own definition, no import anywhere else in `src/`. **Confirmed dead code, not an excused gap** — there is nothing here to port because nothing upstream reaches it either. |
| 602, 603 | "not ported" (×2) | `.desktop.in`/`.metainfo.xml.in` metadata, and build plumbing (`meson.build`, `.flake8`, `.github/`, `snap/`, `requirements.txt`) | These are packaging/build-system files, not UI or behaviour — outside what `component-identification`/`component-parity` claim as scope (widgets, CSS, signals, actions, text). Naming them "not ported" and saying why is disclosure, not an excuse for a missing *component*. **Flagged as a genuine, separate gap below** (desktop metadata has translatable strings too), but not as an excuse dressed as a decision. |
| 416, 417 | "skipped" (×2) | Toast message text `"{} files skipped"` / `"Added {} drum part, {} files skipped"` | These are literal product strings (upstream toast copy), not a claim about the port's own work. Noise match. |

No hit in this run reads as an unmade decision presented as settled. The
`find-excuses.sh` output does not need the confessional rewrite — every match
is either a verified-dead-code call, a literal product string, or packaging
scope correctly disclosed as out of scope.

## The real accountability finding: a possible false green in `spec/`

The sharpest thing this audit found is not a hidden TODO — it's an
**appearance of a passing test suite that is not one.**
`spec/README.md` describes a fully-built RSpec harness (`kettle-test`,
`stub_env`, time-travel helpers, coverage via `kettle-soup-cover`) in prose
confident enough to read as "this works; here's how to use it." I ran it:

```
nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(
  ["--format", "progress", "--require", "spec_helper", "spec"])'
→ LoadError: cannot load such file -- kettle/test/rspec
→ 0 examples, 0 failures, 2 errors occurred outside of examples
```

`rake spec` and `bundle exec rspec` also fail outright (see
`test-parity.md` for both transcripts). **Nobody has to claim this suite
passes for it to function as a false green** — a reviewer who reads
`spec/README.md`, sees `kettle-test` in the gemspec's development
dependencies, and does not personally invoke the runner would reasonably
conclude a test suite exists and is maintained. It does not run, at all, in
this fork's own Nix environment, and 0 examples is not evidence of
correctness no matter how it is phrased. This is the single highest-severity
finding in this audit: the thing most likely to be mistaken for a green
signal is the one definitively proven broken by actually running it.

The actual verified-passing checks — the two `test/*.rb` driver scripts, 46
and 19 "ok" lines respectively — are real, and I ran both myself rather than
taking the "46 of 46 checks passed" claim in the runtime gate on faith. That
claim is accurate. What is not accurate, anywhere it might be assumed, is
that `spec/` backs it up.

## Secondary finding: desktop metadata strings are also untranslated and unported

`.desktop.in`/`.metainfo.xml.in` are correctly disclosed as "not ported" in
the component inventory (packaging, not UI), but both files carry their own
translatable strings (app name, summary, description) that are part of
upstream's `po/` extraction (`POTFILES.in` includes them) and are visible to
a user in GNOME Software / the app grid regardless of in-app i18n. This
compounds the `translation-parity.md` gap rather than standing apart from
it — recorded here because it is exactly the kind of gap that "not ported,
by decision" language could quietly absorb if not checked against
`POTFILES.in` directly, which I did: `cat /tmp/dm-upstream/po/POTFILES.in`
lists both files among its 17.

## Summary

- No TODO/FIXME/stub/"not implemented"/"for now"/"in a future" language in
  `lib/` or `exe/`.
- No unmade decision in `.reports/` presented as settled; every
  `find-excuses.sh` hit traced to either verified dead code, literal product
  copy, or correctly-scoped packaging disclosure.
- One severe false-green risk: `spec/`'s RSpec harness is advertised in
  prose and in the gemspec's dependency list but cannot load or run in this
  fork's own dev shell — 0 examples have ever executed successfully.
- One compounding translation gap not previously named: desktop/metainfo
  strings, which `translation-parity.md`'s count already implicitly includes
  via `POTFILES.in` but which the inventory's "not ported" packaging note
  could be misread as excusing.
