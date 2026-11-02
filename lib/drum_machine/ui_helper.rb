# frozen_string_literal: true

require "adwaita"

module DrumMachine
  # UIHelper — ported from upstream's src/services/ui_helper.py.
  #
  # The bridge between the playback loop and the toggles on screen: it moves
  # the playhead highlight down a whole column of toggles, clears the grid,
  # pushes a loaded pattern into it and forwards carousel scrolls.
  #
  # Upstream reaches each toggle with getattr(window, "<part>_toggle_<n>") —
  # every toggle is stashed as a dynamic attribute on the window. This port
  # asks the grid's registry instead (DrumGrid#toggle), which is the same
  # lookup without the string-built attribute names.
  class UIHelper
    def initialize(window)
      @window = window
    end

    def beats_per_page = @window.drum_machine_service.beats_per_page

    def highlight_playhead_at_beat(beat_index)
      set_playhead_highlight_for_beat(beat_index, true)
    end

    def remove_playhead_highlight_at_beat(beat_index)
      set_playhead_highlight_for_beat(beat_index, false)
    end

    # Clears the highlight from every rendered beat. Upstream notes this is
    # heavier than it needs to be; it only runs on stop, so it stays as it is.
    def clear_all_playhead_highlights
      rendered_beat_count.times { |beat_index| set_playhead_highlight_for_beat(beat_index, false) }
    end

    def deactivate_all_toggles_in_ui
      @window.sound_service.drum_part_manager.all_parts.each do |part|
        rendered_beat_count.times do |beat_index|
          @window.drum_grid.toggle(part.id, beat_index).then do |toggle|
            if toggle&.active?
              toggle.active = false
            end
          end
        end
      end
    end

    # Pushes a pattern into the toggles. Beats past the last rendered page have
    # no toggle yet, so they are skipped — the carousel grows for them and the
    # next rebuild picks them up.
    def load_pattern_into_ui(drum_parts_state)
      drum_parts_state.each do |part_id, beats|
        beats.each_key do |beat_index|
          @window.drum_grid.toggle(part_id, beat_index).then do |toggle|
            if toggle
              toggle.active = true
            end
          end
        end
      end
    end

    def set_bpm_in_ui(bpm_value)
      @window.bpm_spin_button.value = bpm_value
    end

    def scroll_carousel_to_page(page_index)
      @window.scroll_carousel_to_page(page_index)
    end

    private

      def rendered_beat_count = beats_per_page * @window.drum_grid.carousel&.n_pages.to_i

      def set_playhead_highlight_for_beat(beat_index, highlight_on)
        @window.sound_service.drum_part_manager.all_parts.each do |part|
          @window.drum_grid.toggle(part.id, beat_index).then do |toggle|
            if toggle && highlight_on
              toggle.add_css_class("toggle-active")
            elsif toggle
              toggle.remove_css_class("toggle-active")
            end
          end
        end
      end
  end
end
