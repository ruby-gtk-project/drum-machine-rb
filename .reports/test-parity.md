# Test parity — drum-machine-rb

## Upstream has no automated tests

```
git ls-tree -r --name-only origin/main | grep -i test   →  (nothing)
grep -rn "unittest\|pytest" Makefile meson.build          →  (nothing)
```

Upstream ships no `tests/` directory, no `unittest`/`pytest` wiring in its
`Makefile` or `meson.build`, and no test job beyond lint in
`.github/workflows/ci.yml` (not re-checked line by line here, but no test
runner is referenced anywhere in the build files). So "is every upstream test
ported" is **vacuously true: zero upstream tests exist to port.** This is not
a gap, but it also means the port's own test posture is entirely the port's
own responsibility — there is no upstream baseline to fall back on.

## The port's advertised RSpec suite does not run

`spec/` contains `spec_helper.rb` and `README.md` — no actual spec files, no
`*_spec.rb` anywhere in the tree:

```
find . -iname "*spec*" ! -path "./.git/*"
  ./spec, ./spec/README.md, ./spec/spec_helper.rb, ./.rspec, ./.rubocop_rspec.yml,
  ./gemfiles/modular/rspec.gemfile, ./drum-machine-rb.gemspec
```

I ran the exact command the dev shell's own banner advertises as "run the
specs":

```
nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(
  ["--format", "progress", "--require", "spec_helper", "spec"])'
```

Result:

```
LoadError: cannot load such file -- kettle/test/rspec
# ./spec/spec_helper.rb:23:in '<top (required)>'
...
0 examples, 0 failures, 2 errors occurred outside of examples
```

I also ran the standard entry points a reviewer would reach for first:

```
nix develop --command bundle exec rspec     → Gem::Exception: rspec-core is not currently
                                               included in the bundle
nix develop --command rake spec             → "NOTE: kettle-dev isn't installed, or is
                                               disabled for 3.4.9 in the current environment"
```

All three fail. `kettle-test` is listed as a development dependency in
`drum-machine-rb.gemspec`, and `spec/README.md` describes a detailed harness
built on it (`stub_env`, `hide_env`, `pending_for`, time-travel helpers,
`kettle-soup-cover` coverage), but **none of it is reachable from this fork's
Nix dev shell**: `flake.nix` wires in `rspec` as a package
(`pkgs.rubyPackages_3_4.rspec`, line 197) but not `kettle-test`, and there is
no `Gemfile.lock` in the port to pin what `bundle` would otherwise resolve.

**This is the suite the task description warned about: it has never been
executed successfully, by anyone, in this environment, because it cannot be.**
Zero examples have ever run. The `spec/README.md` reads as a finished,
documented test harness — a *false green by appearance* that a reviewer who
does not actually run it would take at face value.

## What actually gates the port today

Two hand-written driver scripts in `test/` (not `spec/`), run directly with
`ruby`, not through `rspec` or `rake`:

- `test/drive_main_window.rb` (289 lines, 49 `d.step` blocks, 46 `d.check`
  assertions) — the window, dialogs, menus, transport, and breakpoint
  behaviour. Ran live: **46 of 46 checks passed, `DRIVE OK`.**
- `test/check_pattern_service.rb` (139 lines) — name utils, drum part
  manager, pattern service round-trips on all six bundled `.mid` patterns,
  WAV sample decoding, and the renderer/encoder. Ran live: **19 of 19 `ok`
  lines, "all checks passed".**
- `test/gtk_driver.rb` — the harness both scripts above are built on
  (headless driving + screenshotting), not itself a test file.

Both scripts pass when actually run, and I ran both myself rather than
trusting the counts. This is real, reproducible coverage of the audio/MIDI
engine and a wide slice of the UI. **But it is not wired into `rake`, `bundle
exec rspec`, CI, or any task a reviewer would run by convention** — it is
only discoverable by reading the dev-shell banner or this report. A
convention (`rake spec`, `rspec`) exists and is broken; the thing that
actually works has no convention pointing at it.

## Gaps

1. **The RSpec suite is non-functional infrastructure, not deferred work.**
   `gemset.nix`/`flake.nix` do not provide `kettle-test`'s load path, so
   `spec_helper.rb` cannot load under any invocation this fork's own tooling
   recommends. Until that's fixed, `spec/` is 0 examples, always, and anyone
   who merges code only checking `spec/` stays green by exercising nothing.
2. **No regression protection ties the two driver scripts to CI** or to a
   named `rake` task — they run only if a human remembers to type the exact
   `nix develop --command xvfb-run -a ruby test/<script>.rb` invocation from
   the dev-shell banner.
3. **File-dialog flows and non-WAV export formats are untested** by either
   script (see `component-parity.md`) — there is no test gap narrower than
   "this code path has never run once", because it has not.
4. **Translation behaviour has no test on either side** — moot today only
   because there is no translation surface at all (see
   `translation-parity.md`), but worth recording so a future `po/` import
   does not also arrive untested.

None of this is excused anywhere in the tree — `lib/`, `exe/`, and the
existing `.reports/component-inventory.md` make no claim that the RSpec
suite runs. The risk is specifically that a reader who sees `spec/README.md`
and a populated `drum-machine-rb.gemspec` test-dependency list, without
running `bundle exec rspec` themselves, would conclude tests exist and pass.
They do not exist as runnable examples, and "0 examples, 0 failures" is not
the same claim as "passed".
