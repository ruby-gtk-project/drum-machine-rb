# frozen_string_literal: true

require "adwaita"
require_relative "constants"

module DrumMachine
  # ExportPhase / ExportProgressHandler / ExportTask — ported from upstream's
  # src/utils/export_progress.py.
  #
  # Not widgets, but between them they drive four of the export dialog's: the
  # progress bar, the status box and its two labels.
  module ExportPhase
    PREPARING = :preparing
    RENDERING = :rendering
    SAVING = :saving
  end

  # Handles export progress updates and UI thread coordination.
  class ExportProgressHandler
    # One [status, detail] pair per phase, with the fallback upstream falls
    # back to for anything it does not recognise.
    PHASE_LABELS = {
      ExportPhase::PREPARING => ["Preparing…", "Initializing…"],
      ExportPhase::RENDERING => ["Rendering audio…", "Processing beats…"],
      ExportPhase::SAVING    => ["Saving file…", "Writing to disk…"],
    }.freeze

    FALLBACK_LABELS = ["Exporting…", "Processing…"].freeze

    def initialize(progress_bar, status_overlay, status_label, detail_label)
      @progress_bar = progress_bar
      @status_overlay = status_overlay
      @status_label = status_label
      @detail_label = detail_label
      @pulse_source = nil
      @active = false
    end

    def active? = @active

    def start_progress_tracking
      @active = true
      @progress_bar.visible = true
      @status_overlay.visible = true
      start_pulse
    end

    def stop_progress_tracking
      @active = false
      @progress_bar.visible = false
      @status_overlay.visible = false
      stop_pulse
    end

    # Called from the export thread, so the widget writes are handed to the
    # main loop rather than done in place.
    def update_phase(phase)
      PHASE_LABELS.fetch(phase, FALLBACK_LABELS).then do |status, detail|
        GLib::Idle.add do
          @progress_bar.pulse
          @status_label.label = status
          @detail_label.label = detail
          false
        end
      end
    end

    private

      # Upstream pulses from a daemon thread that sleeps between frames; a GLib
      # timeout is the same beat without the thread.
      def start_pulse
        @pulse_source ||= GLib::Timeout.add((Constants::PULSE_INTERVAL_SECONDS * 1000).to_i) do
          @progress_bar.pulse
          @active
        end
      end

      def stop_pulse
        @pulse_source.then do |source|
          if source
            GLib::Source.remove(source)
            @pulse_source = nil
          end
        end
      end
  end

  # Manages the background export operation.
  class ExportTask
    attr_accessor :current_process

    def initialize(audio_export_service, progress_handler)
      @audio_export_service = audio_export_service
      @progress_handler = progress_handler
      @export_thread = nil
      @cancelled = false
      @current_process = nil
    end

    def cancelled? = @cancelled

    def running? = @export_thread&.alive? == true

    # Starts the export on its own thread. Returns false when one is already
    # running, which is what keeps a second click from doubling up.
    def start_export(drum_parts_state, bpm, filename, repeat_count, metadata, on_complete)
      if running?
        false
      else
        @cancelled = false
        @progress_handler.start_progress_tracking
        @export_thread = Thread.new do
          export_worker(
            drum_parts_state,
            bpm,
            filename,
            repeat_count,
            metadata,
            on_complete,
          )
        end
        true
      end
    end

    def cancel_export
      @cancelled = true
      kill_current_process
      @progress_handler.stop_progress_tracking
    end

    private

      def kill_current_process
        @current_process.then do |pid|
          if pid
            begin
              Process.kill("KILL", pid)
            rescue Errno::ESRCH, Errno::EPERM
              nil
            end
          end
        end
      end

      def export_worker(drum_parts_state, bpm, filename, repeat_count, metadata, on_complete)
        begin
          unless @cancelled
            @audio_export_service.export_audio(
              drum_parts_state,
              bpm,
              filename,
              progress_callback: @progress_handler.method(:update_phase),
              repeat_count:      repeat_count,
              metadata:          metadata,
              export_task:       self,
            ).then { |success| complete(on_complete, success, filename) }
          end
        rescue StandardError => e
          warn "drum-machine: export error: #{e.message}"
          complete(on_complete, false, filename)
        ensure
          GLib::Idle.add do
            @progress_handler.stop_progress_tracking
            false
          end
        end
      end

      def complete(on_complete, success, filename)
        unless @cancelled
          GLib::Idle.add do
            on_complete.call(success, filename)
            false
          end
        end
      end
  end
end
