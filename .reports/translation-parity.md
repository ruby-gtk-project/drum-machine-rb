# Translation parity — drum-machine-rb

## The census

```
cd /tmp/dm-upstream
grep -c '^msgid' po/drum-machine.pot        → 238 (237 real + the header's empty msgid)
cat po/LINGUAS                                → bg ca de el en_GB eo es eu fa fi fr he hu it ka
                                                 kk nb nl pt pt_BR ru sl sr sv tr uk uz zh_CN  (28)
po/*.po                                       → 28 files, one per LINGUAS entry, plus the .pot
```

Upstream ships **237 distinct msgids**, **28 translated locales**, and a
`POTFILES.in` naming 17 source files to extract from.

```
cd /home/nathan/src/github/ruby-gtk-project/drum-machine-rb
find . -iname "*.po" -o -iname "*.pot" -o -iname "*.mo"   → (nothing, repo-wide)
grep -rn "gettext\|GetText\|_(\"" lib/ exe/                → (nothing)
```

## Verdict: total gap

- **Key sets equal?** No. Port: 0 msgids. Upstream: 237. 0/237 survive.
- **Byte-identical?** N/A — there is nothing to compare bytes against,
  because no string in `lib/` or `exe/` goes through a translation marker at
  all. Every user-visible string the component-inventory catalogues (toast
  messages, dialog titles, button labels, tooltips, accessibility strings,
  the "Default Patterns" menu section title, the six pattern names, the ten
  default part names, `translator-credits`, the shortcuts-dialog labels) is
  a bare Ruby literal.
- **Languages ship?** No. 0 of 28. There is no `po/` directory, no
  `LINGUAS`, no `.mo` build step, and no gettext runtime wiring
  (`GetText.bindtextdomain`, `FastGettext`, or equivalent) anywhere in
  `lib/drum_machine.rb`, `exe/drum-machine`, `flake.nix`, or the gemspec.

Per the `translation-parity` skill's own framing, this is not a state the
project is entitled to call "not ready yet" or "English-only for now" — both
are explicitly named in the skill as non-states. It is a plain count: **0 of
237 messages, 0 of 28 languages**, and every one of those 28 donated
catalogues is currently dead on this branch — not deferred, discarded, in
the sense that nothing in the port would resume using them even if the `po/`
directory were copied in, because no string is marked to look anything up.

## Where this is and is not already disclosed

`.reports/component-inventory.md`'s "What remains for later steps" section
already says plainly: *"`po/` has not been carried over at all; upstream
ships 28 locales plus `drum-machine.pot`, and `POTFILES.in` lists 17 files."*
That is an honest, specific disclosure, not an excuse — it names the count
and does not claim it is done. This report confirms that disclosure is
accurate and adds the exact numbers (237 msgids, not just "the pot file")
and the fact that there is zero gettext call-site infrastructure in `lib/` to
build on, which the existing note does not spell out: this is not "copy
`po/` over", it is "mark ~237 strings across every file in the inventory's
21 units, then copy `po/` over, then wire a `.mo` build and a runtime
`bindtextdomain`/`textdomain` call that nothing in the port currently makes."

## What a real translation-parity pass requires here (not yet started)

1. Mark every string the component inventory already lists per unit with a
   gettext call, using **upstream's exact msgid bytes** (readable straight
   out of `po/drum-machine.pot` — e.g. `msgid "Open…"`, `msgid "BPM"`,
   `msgid "Added: %s"`), not a retyped equivalent.
2. Decide and wire the Ruby gettext path (`gettext` gem vs `FastGettext`) and
   add it to `flake.nix`/the gemspec — currently absent.
3. Copy `po/` (28 `.po` + `drum-machine.pot` + `LINGUAS`) into the port
   unchanged, build `.mo`s, and load the right locale at startup.
4. Re-run the `msgid-census.sh` diff from the skill between
   `po/drum-machine.pot` and a freshly extracted port catalogue until it is
   empty.

None of this exists yet. This is the largest single gap found in this
audit.
