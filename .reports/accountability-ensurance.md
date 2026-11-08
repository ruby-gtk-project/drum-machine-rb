# Accountability ensurance — drum-machine-rb

## Scope grepped

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|unimplemented|stub" lib/ exe/
  → (nothing)

bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
  → 18 hits: 17 in .reports/*.md, 1 in lib/drum_machine/translation.rb:7
```

(The previous round found 7 hits, all in `.reports/component-inventory.md`.
This round's number is higher only because this round's own
`.reports/accountability-ensurance.md` and `.reports/component-inventory.md`
both quote the construction while discussing it, which the scanner matches
and which is the documented exemption — "a document *about* excuses" — not a
new finding. The one hit outside `.reports/` is new to this analysis, not to
the tree: it has been in `translation.rb` since it was written.)

## The one real hit: `lib/drum_machine/translation.rb:7`

```ruby
# Translation — the gettext wiring every file with user-visible strings
# needs. Not ported from one upstream file: it stands in for upstream's
# Meson `i18n.gettext()` call plus the `locale/`-relative `.mo` lookup
# GLib does at runtime, neither of which has a single source file.
```

Read against the rule ("no sentence a reader could mistake for a decision"):
this sentence is not excusing a *missing behaviour* — the behaviour
(gettext wiring, domain binding, `.mo` lookup) is built, two lines down, and
works (`translation-parity.md` confirms 243/259 messages reachable through
exactly this file). "Not ported from one upstream file" is stating a 1-to-many
file mapping, which `component-parity.md`'s own rules carve out as a named
correspondence, not a gap. **This is not the failure the skill exists to
catch** — nobody reading it would conclude a feature is missing, because no
feature is named as missing. It is flagged here anyway, because the
construction matches and a borderline case is still worth a reader's eyes:
if this file is ever used as the template for a future excuse ("not ported
from one upstream file" applied to something that *is* missing a behaviour),
it would launder exactly the way the skill warns about. Recommend tightening
the wording away from "Not ported" regardless, since the phrase itself is on
the skill's watch-list and a calm reading of one instance is how a reader's
guard comes down for the next one. Not rewritten as a confession, because
rewriting a true, non-excusing architecture note as a confession of
incompetence would itself be dishonest — the rule is "no false sanction",
not "no explanation of any kind, ever".

## The hits inside `.reports/`

All 17 are the two earlier rounds' own analysis of the construction (this
file and `component-inventory.md` both quote phrases like "not ported" and
"no Ruby equivalent" while explaining why each instance is or isn't an
excuse). This is the skill's stated exemption and is not re-litigated row by
row here; the previous round's reasoning (in the version of this file prior
to this edit, preserved in git history) already traced each one to either
verified dead code, a literal product string, or correctly-scoped packaging
disclosure, and nothing in this round's independent re-reading overturns
that.

One correction to the previous round's own text, found while re-verifying it
for this pass: the earlier `.reports/component-inventory.md` "What remains
for later steps" section still asserts, in the committed tree, that
"`po/` has not been carried over at all" and that `.desktop.in`/
`.metainfo.xml.in` "are not ported". **Both are false as of this round** —
`po/`, `LINGUAS`, `POTFILES.in`, and both metadata files all exist on `ruby`
today (see `translation-parity.md`, `component-identification.md`). That
section of `component-inventory.md` is not an excuse construction the
scanner flags, but it is the same underlying failure mode one level up: a
document stating a gap is open when it has in fact been closed is exactly as
misleading to the next reader as a document stating a gap is closed when it
is open. Recorded here because `accountability-ensurance` is the ledger that
exists to catch a document being trusted past its truth, regardless of which
direction the staleness points.

## The false-green risk from the previous round: resolved, and said so

The previous round's single highest-severity finding was that `spec/`'s
RSpec harness advertised itself in prose (`spec/README.md`, the gemspec's
dev dependencies) while being unable to load at all — `0 examples, 0
failures, 2 errors occurred outside of examples` under every invocation
tried. I re-ran all three invocations that report tried, from a clean shell,
rather than trusting either that report's "broken" verdict or the current
runtime gate's "green" framing:

```
bundle exec rspec     → still fails (rspec-core not in the bundle)
rake spec              → still fails (kettle-dev not installed/disabled)
rake spec_direct       → 6 examples, 0 failures   (xvfb-run required — see test-parity.md)
```

So the false-green risk as *originally described* — "nobody has ever run
this suite successfully" — is **fixed**: `rake spec_direct` is a real,
passing invocation, and it is the one the dev-shell banner actually
recommends. But the fix is partial in a way worth stating plainly rather
than rounding up to "resolved": the two conventional entry points a reviewer
reaches for without reading the banner (`bundle exec rspec`, `rake spec`)
**still fail**, for different reasons than before (a missing bundled gem;
`kettle-dev` disabled for this Ruby version) rather than the original
`LoadError`. A reviewer who runs `rake spec` today, sees the "isn't
installed, or is disabled" note, and does not go read the banner for the
alternate command name would reach the same false conclusion the previous
round warned about, via a different stack trace. This is recorded as an
open, lower-severity version of the same risk in `test-parity.md`, not
re-claimed as fully closed here.

## Summary

- No `TODO`/`FIXME`/`not implemented`/"for now"/"in a future" language in
  `lib/` or `exe/`.
- One real excuse-shaped sentence outside `.reports/`
  (`translation.rb:7`), judged not to be excusing a missing behaviour on
  inspection, flagged anyway for wording.
- One stale claim found and corrected: `component-inventory.md` describes
  `po/` and the desktop/metainfo files as unported; both exist today. Fixed
  in `component-identification.md` this round.
- The previous round's severe false-green finding (RSpec suite unrunnable)
  is substantively fixed — `rake spec_direct` passes — but the two
  conventional commands a reviewer would try first are still broken for
  other reasons, which is a live, named, lower-severity residue of the same
  risk, not a clean bill.
- New material finding surfaced by this round's `translation-parity` pass,
  not previously recorded anywhere in `.reports/`: 16 upstream msgids
  (`DEFAULT_DRUM_PARTS`, `DEFAULT_PATTERNS` in `constants.rb`) are bare
  string literals in the port with no translation marker at all. This is
  not excused anywhere — no comment near those two arrays claims they are
  intentionally left English — it is simply a gap nobody had found yet.
  Recording it here, in addition to `translation-parity.md` and
  `component-parity.md`, satisfies this skill's own rule that a real gap
  gets named with file:line rather than left implicit.

## This round's own finding: the previous round's "Closed" was a false green

This is the exact failure this skill exists to catch, and it was committed
by this same audit chain, not by the porting work. The round-2
`translation-parity.md` stated, in its own voice, not hedged:

> **Closed.** ... 259/259 messages (100%) byte-identical and reachable; 0
> gaps.

That line was never re-derived from a full fresh census against the
complete upstream key set — it was derived from re-running the census
**only on the 16 keys the round already knew about** (the `constants.rb`
fix) and generalising the result to "0 gaps" for all 259. Re-running
`msgid-census.sh` fresh this round, over the full key set, with no prior
result assumed, surfaces 23 keys the port's code never reaches, of which 7
are a real, newly-named gap (the four controls' accessible
label/description text in `window.ui` — `lib/drum_machine/window.rb` never
calls `update_property` or sets any accessible property at all; see
`component-parity.md` and `translation-parity.md`'s "Round 3" sections for
the full trace with file:line on both sides). Rather than being an excuse
construction (no sentence anywhere claimed these 7 were deliberately
skipped — they were simply never looked for, which is a different and in
some ways worse failure: a *verified-closed* ledger is harder for the next
reader to re-open than an *unexamined* one, because it reads as checked).

I did not catch this by re-reading the previous reports harder; I caught it
by distrusting a green verdict enough to re-run the exact command that
produced it, against the full input, instead of the narrower one. That is
the standing instruction this skill exists to enforce, restated as a
finding against this audit chain's own prior round rather than against the
port: **a report that says "closed" after fixing the one thing it went
looking for, without re-deriving the total, is a false green**, structurally
identical to the thing this skill is here to catch in `PORTING.md`-style
documents — the party that most needs re-checking is the author of the
"all clear."
