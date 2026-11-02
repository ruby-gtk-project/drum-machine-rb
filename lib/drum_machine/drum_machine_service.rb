# frozen_string_literal: true

require "adwaita"
require_relative "constants"
require_relative "pattern_service"

module DrumMachine
  # DrumMachineService — ported from upstream's
  # src/services/drum_machine_service.py (which also stands in for
  # src/interfaces/player.py, an ABC with no Ruby meaning).
  #
  # Owns the pattern state, the tempo, the volume and the playback loop. The
  # loop runs on its own thread, exactly as upstream's does, and every touch of
  # a widget from that thread goes through GLib::Idle.add.
  class DrumMachineService
    attr_accessor :drum_parts_state, :beats_per_page, :playing_beat, :playing
    attr_reader :bpm, :last_volume, :total_beats, :active_pages, :pattern_service

    def initialize(window, sound_service, ui_helper)
      @window = window
      @sound_service = sound_service
      @ui_helper = ui_helper
      @playing = false
      @bpm = Constants::DEFAULT_BPM
      @last_volume = Constants::DEFAULT_VOLUME
      @play_thread = nil
      @stop_requested = false
      @drum_parts_state = create_empty_drum_parts_state
      @pattern_service = PatternService.new(window)
      @total_beats = Constants::NUM_TOGGLES
      @beats_per_page = Constants::NUM_TOGGLES
      @active_pages = 1
      @playing_beat = -1
    end

    def playing? = @playing

    # One empty beat map per drum part. Rebuilt whenever the set of parts
    # changes, so a removed part leaves no state behind.
    def create_empty_drum_parts_state
      @sound_service.drum_part_manager.all_parts.to_h { |part| [part.id, {}] }
    end

    def play
      @playing = true
      @stop_requested = false
      @play_thread = Thread.new { play_drum_sequence }
    end

    def stop
      @playing = false
      @stop_requested = true
      @sound_service.stop_all_sounds
      @ui_helper.clear_all_playhead_highlights
      @playing_beat = -1
      @play_thread.then do |thread|
        if thread
          thread.join
          @play_thread = nil
        end
      end
    end

    # The pattern is as long as its highest active beat rounds up to, in whole
    # pages; an empty pattern is one page.
    def update_total_beats
      highest_active_beat.then do |max_beat|
        if max_beat.nil?
          @active_pages = 1
        else
          @active_pages = (max_beat / @beats_per_page) + 1
        end
      end
      @total_beats = @active_pages * @beats_per_page
    end

    def set_bpm(bpm)
      @bpm = bpm
    end

    # Volume is 0–100 from the scale button. Zero is remembered as a mute
    # rather than as the volume to come back to.
    def set_volume(volume)
      @sound_service.set_volume(volume)
      if volume != 0
        @last_volume = volume
      end
    end

    def clear_all_toggles
      @drum_parts_state = create_empty_drum_parts_state
      @ui_helper.deactivate_all_toggles_in_ui
    end

    def save_pattern(file_path)
      @pattern_service.save_pattern(file_path, @drum_parts_state, @bpm)
    end

    def load_pattern(file_path)
      @ui_helper.deactivate_all_toggles_in_ui
      @pattern_service.load_pattern(file_path).then do |state, bpm|
        @drum_parts_state = state
        @bpm = bpm
      end

      # A pattern may have invented temporary parts, so both the column and the
      # grid have to come back with the new set of rows.
      @window.drum_grid.rebuild_drum_parts_column
      @window.drum_grid.rebuild_carousel
      @ui_helper.set_bpm_in_ui(@bpm)
    end

    def preview_drum_part(part_id)
      @sound_service.drum_part_manager.get_part_by_id(part_id).then do |part|
        if part
          @sound_service.preview_sound(part_id)
        end
      end
    end

    def add_drum_part_state(part_id)
      @drum_parts_state[part_id] = {}
    end

    def add_new_drum_part(file_path, name)
      @sound_service.drum_part_manager.add_custom_part(name, file_path).then do |new_part|
        if new_part
          @sound_service.reload_sounds
          add_drum_part_state(new_part.id)
          @window.drum_grid.add_drum_part(new_part)
        end
        new_part
      end
    end

    def replace_drum_part(drum_id, file_path, name)
      @sound_service.drum_part_manager.replace_part(drum_id, file_path, name).then do |part|
        if part
          @sound_service.reload_specific_sound(drum_id)
          @window.drum_grid.update_drum_button(drum_id)
          update_total_beats
        end
        part
      end
    end

    def remove_drum_part(drum_id)
      @sound_service.drum_part_manager.remove_part(drum_id).then do |removed|
        if removed
          @drum_parts_state.delete(drum_id)
          @window.drum_grid.rebuild_drum_parts_column
          @window.drum_grid.rebuild_carousel
          update_total_beats
        else
          warn "drum-machine: failed to remove drum part: #{drum_id}"
        end
        removed
      end
    end

    private

      def highest_active_beat
        @drum_parts_state.each_value.filter_map { |beats| beats.keys.max }.max
      end

      # Sixteenth notes: four subdivisions to the beat.
      def delay_per_step = 60.0 / @bpm / Constants::GROUP_TOGGLE_COUNT

      def play_drum_sequence
        current_beat = 0
        while @playing && !@stop_requested
          if current_beat >= @total_beats
            current_beat = 0
          end

          play_beat(current_beat)
          sleep(delay_per_step)
          current_beat.then do |beat|
            GLib::Idle.add do
              @ui_helper.remove_playhead_highlight_at_beat(beat)
              false
            end
          end
          current_beat += 1
        end
      end

      def play_beat(beat)
        GLib::Idle.add do
          @ui_helper.highlight_playhead_at_beat(beat)
          false
        end
        @playing_beat = beat

        if (beat % @beats_per_page).zero?
          (beat / @beats_per_page).then do |target_page|
            GLib::Idle.add do
              @ui_helper.scroll_carousel_to_page(target_page)
              false
            end
          end
        end

        @sound_service.drum_part_manager.all_parts.each do |part|
          if @drum_parts_state.fetch(part.id, {})[beat]
            @sound_service.play_sound(part.id)
          end
        end
      end
  end
end
