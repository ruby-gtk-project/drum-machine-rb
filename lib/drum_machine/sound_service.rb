# frozen_string_literal: true

require_relative "constants"
require_relative "drum_part_manager"

module DrumMachine
  # SoundService — ported from upstream's src/services/sound_service.py (which
  # also stands in for src/interfaces/sound.py, an ABC with no Ruby meaning).
  #
  # Upstream plays samples through pygame's mixer. There is no pygame for Ruby,
  # and GTK's own Gtk::MediaFile needs a GStreamer playbin this fork's closure
  # does not carry, so playback here hands each hit to the first command-line
  # player found on PATH. That keeps the service's contract identical — load,
  # play, set volume, stop everything — and matches what upstream already does
  # for encoding, where ffmpeg is a subprocess too.
  #
  # MIXER_CHANNELS caps how many hits may be in flight at once, the same cap
  # pygame.mixer.set_num_channels gives upstream.
  class SoundService
    # Each entry is [executable, argument builder]. The builder takes the file
    # path and a 0.0–1.0 volume and returns the full argv.
    PLAYERS = [
      ["pw-play", ->(path, volume) { ["pw-play", "--volume=#{format("%.3f", volume)}", path] }],
      ["paplay", ->(path, volume) { ["paplay", "--volume=#{(volume * 65_536).round}", path] }],
      ["aplay", ->(path, _volume) { ["aplay", "-q", path] }],
      ["ffplay", ->(path, volume) { ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-volume", (volume * 100).round.to_s, path] }],
      ["afplay", ->(path, volume) { ["afplay", "-v", format("%.3f", volume), path] }],
    ].freeze

    attr_reader :drum_part_manager

    def initialize(bundled_sounds_dir)
      @bundled_sounds_dir = bundled_sounds_dir
      @drum_part_manager = DrumPartManager.new(bundled_sounds_dir)
      @sounds = {}
      @current_volume = 1.0
      @playing = []
      @player = nil
      @player_resolved = false
    end

    # "Loading" a sound is checking the file is there and remembering its path;
    # the player process reads it afresh on every hit.
    def load_sounds
      @sounds = {}
      @drum_part_manager.all_parts.each do |part|
        if part.file_available?
          @sounds[part.id] = part.file_path
        elsif !part.temporary?
          warn "drum-machine: error loading sound #{part.name}: #{part.file_path} is missing"
        end
      end
      @sounds
    end

    def reload_sounds = load_sounds

    def reload_specific_sound(part_id)
      @drum_part_manager.get_part_by_id(part_id).then do |part|
        if part&.file_available?
          @sounds[part_id] = part.file_path
        else
          @sounds.delete(part_id)
        end
      end
    end

    def play_sound(part_id)
      @sounds[part_id].then do |path|
        if path && player
          spawn_player(path)
        end
      end
    end

    def preview_sound(part_id) = play_sound(part_id)

    def set_volume(volume)
      @current_volume = volume.to_f / 100
    end

    def volume = @current_volume

    def stop_all_sounds
      @playing.each do |pid|
        begin
          Process.kill("TERM", pid)
        rescue Errno::ESRCH, Errno::EPERM
          nil
        end
      end
      reap
      @playing = []
    end

    # The player this machine has, or nil when it has none. Resolved once, so a
    # machine with no player does not pay for a PATH walk on every beat.
    def player
      unless @player_resolved
        @player_resolved = true
        @player = PLAYERS.find { |name, _argv| executable?(name) }
        if @player.nil?
          warn "drum-machine: no audio player found on PATH (#{PLAYERS.map(&:first).join(", ")}); playback is silent"
        end
      end
      @player
    end

    private

      def spawn_player(path)
        reap
        if @playing.length < Constants::MIXER_CHANNELS
          @playing << Process.spawn(
            *@player.last.call(path, @current_volume),
            out: File::NULL,
            err: File::NULL,
          )
        end
      end

      # Collects finished players so the channel count reflects what is really
      # still sounding.
      def reap
        @playing = @playing.reject do |pid|
          begin
            !Process.waitpid(pid, Process::WNOHANG).nil?
          rescue Errno::ECHILD
            true
          end
        end
      end

      def executable?(name)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          File.executable?(File.join(dir, name))
        end
      end
  end
end
