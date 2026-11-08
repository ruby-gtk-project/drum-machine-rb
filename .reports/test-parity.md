# Test parity — drum-machine-rb

| | |
|---|---|
| Upstream | `main` @ `fe31c4c` |
| Port | `ruby` @ `adc4970` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test commands run this round | `nix develop --command xvfb-run -a rake spec` (now works; alias added), `nix develop --command xvfb-run -a rake test` (now works; runs all three suites), `nix develop --command xvfb-run -a rake drive` |

## Upstream has no test suite

```
git -C /tmp/dm-upstream ls-tree -r --name-only HEAD | grep -iE 'test|spec'   → (nothing)
grep -rn 'unittest\|pytest' /tmp/dm-upstream/Makefile /tmp/dm-upstream/meson.build   → (nothing)
```

No `tests/` directory, no test target in `Makefile`/`meson.build`, and
`.github/workflows/ci.yml` runs lint only. Parity is **0/0, met trivially**.
**The port therefore inherits no safety net from upstream** — every check
below was written for the port and pins nothing upstream considered worth
pinning down.

## What actually gates the port, run live this round

I re-ran all three, from a clean shell, rather than trusting any prior
report's numbers:

### `rake spec_direct` (RSpec, `spec/`)

```
nix develop --command xvfb-run -a rake spec_direct
...
Randomized with seed ...
......
Finished in 0.01485 seconds (files took 6.33 seconds to load)
6 examples, 0 failures
```

**This is a change from the state a prior round of this audit found and
recorded** (`git log` shows a "Translation parity, a running kettle-test
suite, ..." commit between then and now): the suite previously failed to
load (`LoadError: cannot load such file -- kettle/test/rspec`, 0 examples) no
matter which of `bundle exec rspec` / `rake spec` / the raw `RSpec::Core::Runner`
invocation was used. Today:

- `bundle exec rspec` **still fails** — `rspec-core is not currently included
  in the bundle` (the Gemfile/lockfile the fork's `bundle` resolves against
  does not have it).
- `rake spec` **still fails** — `kettle-dev isn't installed, or is disabled
  for 3.4.9 in the current environment`.
- `rake spec_direct` — the dev shell's own banner-advertised command —
  **works and passes**: 6 examples (the 6 `it` blocks in
  `spec/drum_machine/name_utils_spec.rb`), 0 failures, run headless under
  `xvfb-run` because `spec_helper.rb` requires `drum/machine/rb`, which
  requires `gtk4`, which needs a display even to load the library.

So the RSpec suite is real and green, but **only through the one command
the dev shell banner names**, not through the two conventional entry points
(`bundle exec rspec`, `rake spec`) a reviewer reaches for first. That
mismatch is itself worth recording even though the suite passes: a reviewer
who tries the conventional command first and stops there will wrongly
conclude the suite is still broken.

`spec/` covers exactly one upstream file's worth of logic
(`name_utils.py` → `name_utils.rb`), 6 cases. Everything else the suite
could pin — `drum_part_manager`, `pattern_service`, `sound_service`,
`audio_renderer`, `drum_machine_service` — has no `*_spec.rb` at all; the
equivalent coverage for those lives only in `test/check_pattern_service.rb`,
outside RSpec.

### `rake drive` (`test/drive_main_window.rb`, headless GTK driver)

```
nix develop --command xvfb-run -a rake drive
...
47 of 47 checks passed
DRIVE OK
```

Matches the runtime gate for this round (`drive_ok=true`, 47/47, 0 failed).
I ran it myself rather than taking the figure on faith. One blemish inside an
otherwise-clean run: step 24's screenshot capture throws
(`shot 06-half-view failed: RuntimeError: widget produced no render node (not
realised yet?)`) — the *check* for that step (`eight beats per page`, `the
toggles were re-registered`) still passes, only the `tmp/shots/06-half-view.png`
artifact is missing. Not a failed check, but a real defect in the drive
script's screenshot timing worth noting since `tmp/shots/06-half-view.png`
does not actually exist despite being referenced by the shot list.

The 47 checks are broad — window layout, transport, BPM/volume controls,
mute/unmute, carousel paging, toast, half/full-width breakpoint, About,
shortcuts (including an accelerator-agreement check against the actually
bound `win.`/`app.` actions), reset, save-changes, MIDI mapping, export,
context menu, drag placeholder, add/remove part, reset-to-defaults — but it
is UI-level ("a dialog is visible", "ok the tempo rose by one"), not a test
of the audio/MIDI engine's actual output bytes.

### `ruby test/check_pattern_service.rb` (headless)

```
nix develop --command xvfb-run -a ruby test/check_pattern_service.rb
...
all checks passed
```

20 `ok` lines (re-counted this round; the "19" in an earlier draft of this
report undercounted by one): name utils (2), drum part manager (5),
pattern-service load on all six bundled `.mid` patterns (6), a save→load
round trip (1), WAV sample decode/range/stereo checks (4), and the renderer +
WAV encoder (2). This is the one script that actually exercises byte-level
correctness (decoded sample ranges, RIFF header, round-tripped MIDI).

**Correction to an earlier draft of this report:** that draft claimed
`Rakefile`'s `drive` task "does not include `check_pattern_service.rb`" and
that it was "only reachable by typing the invocation by hand". That was
already false when written — `task "drive"` globs every `test/*.rb` except
`gtk_driver.rb`, sorted, which puts `check_pattern_service.rb` first; running
`rake drive` prints `--- check_pattern_service.rb ---` followed by its 20
`ok` lines before `drive_main_window.rb`'s 47 checks. Re-run and confirmed
live this round.

## Round 2: `rake spec` / `rake test` fixed

`bundle exec rspec` and `rake spec` were the two conventional entry points a
reviewer reaches for first, and both failed — one with an actionable error
(`rspec-core is not currently included in the bundle`, because `bundle exec`
resolves against the root `Gemfile`, not the separate `nix/test/Gemfile`
bundle `rake spec_direct` draws on), the other **silently**: `rake spec`
and `rake test` were plain Rake no-ops (kettle-dev's real `spec`/`test`
tasks are disabled on this fork's Ruby 3.4.9, and nothing filled in behind
them), so `rake spec`/`rake test` exited 0 having run nothing — worse than
an error, because it looks green.

Fixed this round: `Rakefile` now defines `spec` (alias for `spec_direct`)
and `test` (`spec_direct` + `drive`, i.e. all three real suites: RSpec,
`check_pattern_service.rb` and the UI driver) whenever kettle-dev has not
already installed its own same-named task. Verified live:

```
nix develop --command xvfb-run -a rake spec
...
6 examples, 0 failures

nix develop --command xvfb-run -a rake test
...
all checks passed            (check_pattern_service.rb)
...
47 of 47 checks passed
DRIVE OK
```

`bundle exec rspec` is left as-is (a Bundler/Gemfile-scoping issue, not a
Rakefile one) and still fails with its original, non-silent error; `rake
spec`/`rake test` are now the single commands that actually run everything,
and they say so (`rake -T`).

## Gaps against "a suite a reviewer would actually run" (superseded above)

1. ~~Two of the port's three real check suites are each one command away
   from looking broken; there is no single command that runs all three.~~
   **Closed this round** — see "Round 2: `rake spec` / `rake test` fixed".
2. **`check_pattern_service.rb`'s checks are not enumerated as named,
   bijectable test cases** the way a `*_spec.rb` file's `it` blocks are —
   they are print-and-count assertions in one script, which is fine as a
   smoke test but means a regression there shows up as "which `ok` line is
   now missing from the tail of a log", not a named failing example. Still
   open.
3. No CI job in the repo (not checked this round beyond the Rakefile; not
   re-confirmed whether `.github/workflows` exists on `ruby` and runs any of
   the commands above automatically). Still open.

## Extra

- `test/drive_main_window.rb` — 47 checks, headless UI/behaviour driver.
- `test/check_pattern_service.rb` — 20 checks at runtime, audio/MIDI engine
  (16 `check(...)` call sites in source; one, "`<pattern>` loads with active
  beats", is inside a loop over the 6 bundled patterns, so it runs 6 times —
  counted by re-running the suite live this round and counting the `ok`
  lines, not by grepping call-site text).
- `test/gtk_driver.rb` — the harness the two files above are built on, not a
  test file itself.
- `spec/drum_machine/name_utils_spec.rb` — 6 RSpec examples.

None of the above is parity work (upstream has nothing to be parity *with*),
and none of it is required to close any upstream-test gap, because there is
none. It is listed so the total testing picture — 47 + 20 + 6 = 73 checks,
run across three different harnesses with three different invocations, two
of which are not reachable through `rake`'s conventional task names — is on
the record rather than only in the runtime-gate's single pass/fail number.

## Round 3: re-ran the gate fresh, and the "63 checks" figure handed to this audit does not match what runs today

Ran `nix develop --command xvfb-run -a rake drive` live, from a clean shell,
not trusting any number carried over from a previous round or from this
round's own brief:

```
--- check_pattern_service.rb ---
... 20 "ok" lines ...
all checks passed
--- drive_main_window.rb ---
... 47 "ok" steps ...
47 of 47 checks passed
DRIVE OK
```

20 + 47 = **67** checks passed, 0 failed — `drive_ok=true` is confirmed
live, but the count is 67, not the 63 this audit round's own brief stated
as the gate. `rake spec_direct` also passes live (6 examples, 0 failures,
already covered above). I am recording the actual number I measured rather
than repeating the figure I was handed, per this skill's own rule about not
re-citing a claim as settled without re-deriving it — the same failure mode
`accountability-ensurance.md` names against the previous round's
"259/259, 0 gaps" translation verdict. The most likely explanation is that
4 checks were added in a commit after whatever figure produced "63" (this
branch's recent history includes "fix rake spec/test and a flaky
screenshot" and two "Inventory upstream components" commits since), not
that anything regressed — every check that runs, passes — but the
discrepancy is worth a reader's eyes rather than silently reconciled,
because a count that moves without anyone updating the number that gates
the round is exactly the kind of untracked drift this audit exists to
surface.
