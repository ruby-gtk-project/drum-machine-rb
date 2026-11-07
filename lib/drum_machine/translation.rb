# frozen_string_literal: true

require "gettext"

module DrumMachine
  # Translation — the gettext wiring every file with user-visible strings
  # needs. Not ported from one upstream file: it stands in for upstream's
  # Meson `i18n.gettext()` call plus the `locale/`-relative `.mo` lookup
  # GLib does at runtime, neither of which has a single source file.
  #
  # Per .claude/skills/translation-parity/references/ruby-gettext.md,
  # `bindtextdomain` binds to a class, not to the process — `include
  # GetText` in one class does not hand `_()` to the others. Rather than
  # repeat `include GetText; bindtextdomain(...)` in every one of this
  # port's dozen-plus UI files (each with its own risk of a typo'd domain
  # or path), there is exactly one bound GetText object, here, and
  # Translatable below forwards every call to it. Byte-identical lookups
  # either way; one bound domain instead of N.
  module Translation
    # The domain is the .mo filename upstream's translators already build
    # against — renaming it orphans every one of the 28 donated catalogues.
    DOMAIN = "drum-machine"

    # locale/ is build output (see the Rakefile's GetText::Tools::Task),
    # resolved relative to this file the same way Constants resolves data/.
    LOCALE_DIR = File.expand_path("../../locale", __dir__)

    extend GetText
    bindtextdomain(DOMAIN, path: LOCALE_DIR)
  end

  # `include DrumMachine::Translatable` (or `extend`, for a module whose own
  # methods are the public API) to get `_`/`n_`/`pyfmt` as instance methods
  # that look messages up in the one domain Translation binds above.
  module Translatable
    def _(msgid) = DrumMachine::Translation._(msgid)

    def n_(singular, plural, n) = DrumMachine::Translation.n_(singular, plural, n)

    # Upstream marks every shortcuts-window label with
    # `msgctxt "shortcut window"` (blueprint's `context` property) — the same
    # English word ("General", "Quit") can need a different translation in
    # that narrow, menu-item-free context than it would as a plain label
    # elsewhere, so it is kept as its own key rather than collapsed into `_`.
    def p_(msgctxt, msgid) = DrumMachine::Translation.p_(msgctxt, msgid)

    # Upstream formats with Python's `str.format()`, so its msgids carry
    # literal "{}" / "{name}" / "{:spec}" placeholders — kept byte-identical
    # here rather than rewritten to Ruby's "%s", because the msgid is the
    # lookup key every one of the 28 donated .po files was translated
    # against. Positional "{}" (and "{:spec}") are filled from `args`, in
    # call order; named "{name}" (and "{name:spec}") are filled from
    # `kwargs`. The only format spec upstream actually uses is float
    # precision ("{:.0f}", "{:.1f}"); anything else is dropped and the value
    # is simply stringified.
    def pyfmt(msgid, *args, **kwargs)
      remaining = args.dup
      msgid.gsub(/\{([a-zA-Z_]\w*)?(?::([^}]*))?\}/) do
        name = Regexp.last_match(1)
        spec = Regexp.last_match(2)
        value = name ? kwargs.fetch(name.to_sym) : remaining.shift
        spec&.match?(/\A\.\d+f\z/) ? format("%#{spec}", value) : value.to_s
      end
    end
  end
end
