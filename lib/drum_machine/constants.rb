# frozen_string_literal: true

require_relative "translation"

module DrumMachine
  # Constants — ported from upstream's src/config/constants.py.
  #
  # The default part and pattern names are the filenames under data/drumkit and
  # data/patterns, so they double as the lookup keys the drum part manager and
  # the pattern menu use. Upstream wraps every one of these in `_()`
  # (src/config/constants.py:25-34 and :38-43) so they are translatable even
  # though they also double as lookup keys; `extend Translatable` gives this
  # module `_` as a module method so the literals below can be marked the
  # same way at load time, before any instance of anything exists.
  module Constants
    extend Translatable

    # Default drum part names shown in the UI.
    DEFAULT_DRUM_PARTS = [
      _("kick"),
      _("kick-2"),
      _("kick-3"),
      _("snare"),
      _("snare-2"),
      _("hihat"),
      _("hihat-2"),
      _("clap"),
      _("tom"),
      _("crash"),
    ].freeze

    # Default rhythm pattern names shown in the UI.
    DEFAULT_PATTERNS = [
      _("Shoot"),
      _("Maybe Rock"),
      _("Boom Boom"),
      _("Night"),
      _("Slow"),
      _("Chill"),
    ].freeze

    NUM_TOGGLES = 16
    GROUP_TOGGLE_COUNT = 4
    DEFAULT_BPM = 120
    DEFAULT_VOLUME = 100

    # Audio rendering constants.
    DEFAULT_FALLBACK_SAMPLE_SIZE = [1000, 2].freeze

    # Progress bar constants, in seconds.
    PULSE_INTERVAL_SECONDS = 1.0

    # Upstream sets pygame's mixer to this many channels. The Ruby port has no
    # pygame mixer, but the number still caps how many hits may overlap.
    MIXER_CHANNELS = 32

    # Supported audio file formats for input/import.
    SUPPORTED_INPUT_AUDIO_FORMATS = [".wav", ".mp3", ".ogg", ".flac"].freeze

    # The app's own data directory — data/ sits next to lib/ in both a checkout
    # and the Nix install, so it is resolved relative to this file.
    def self.data_dir = File.expand_path("../../data", __dir__)
    def self.drumkit_dir = File.join(data_dir, "drumkit")
    def self.patterns_dir = File.join(data_dir, "patterns")
    def self.icons_dir = File.join(data_dir, "icons")
  end
end
