# frozen_string_literal: true

# Plain checks on the non-widget code: the MIDI reader and writer, the WAV
# sample loader, the renderer and the WAV encoder. No display, no main loop.

require "tmpdir"
require_relative "../lib/drum_machine/audio_export_service"
require_relative "../lib/drum_machine/audio_renderer"
require_relative "../lib/drum_machine/constants"
require_relative "../lib/drum_machine/drum_part_manager"
require_relative "../lib/drum_machine/export_formats"
require_relative "../lib/drum_machine/file_encoder"
require_relative "../lib/drum_machine/name_utils"
require_relative "../lib/drum_machine/pattern_service"

FAILURES = []

def check(name)
  if yield
    puts "  ok   #{name}"
  else
    puts "  FAIL #{name}"
    FAILURES << name
  end
rescue StandardError => e
  puts "  ERR  #{name}: #{e.class}: #{e.message}"
  puts e.backtrace.first(4).map { |line| "         #{line}" }.join("\n")
  FAILURES << name
end

# The pattern service only needs a window that answers sound_service and
# drum_machine_service, so this stands in for one.
FakeSoundService = Struct.new(:drum_part_manager)
FakeDrumMachineService = Struct.new(:manager) do
  def create_empty_drum_parts_state = manager.all_parts.to_h { |part| [part.id, {}] }
  def total_beats = 16
end
FakeWindow = Struct.new(:sound_service, :drum_machine_service)

manager = DrumMachine::DrumPartManager.new(DrumMachine::Constants.drumkit_dir)
window = FakeWindow.new(
  FakeSoundService.new(manager),
  FakeDrumMachineService.new(manager),
)
service = DrumMachine::PatternService.new(window)

puts "name utils"
check("underscores and hyphens become spaced title case") do
  DrumMachine::NameUtils.extract_name_from_path("/a/b/my_cool-sample.wav") == "My Cool Sample"
end
check("a stem of only separators falls back") do
  DrumMachine::NameUtils.extract_name_from_path("/a/b/_-.wav") == "Custom Sound"
end

puts "drum part manager"
check("the ten bundled parts load") { manager.all_parts.length == 10 }
check("kick keeps its GM note") { manager.get_part_by_id("default_kick").midi_note_id == 36 }
check("names are titleized") { manager.get_part_by_id("default_kick-2").name == "Kick 2" }
check("a custom part gets a free note") do
  manager.add_custom_part("Extra", File.join(DrumMachine::Constants.drumkit_dir, "kick.wav")).midi_note_id == 40
end
check("reset drops the custom part") do
  manager.reset_to_defaults
  manager.all_parts.length == 10
end

puts "pattern service — the bundled patterns"
DrumMachine::Constants::DEFAULT_PATTERNS.each do |name|
  check("#{name} loads with active beats") do
    manager.reset_to_defaults
    service.load_pattern(File.join(DrumMachine::Constants.patterns_dir, "#{name}.mid")).then do |state, bpm|
      bpm.positive? && state.each_value.any? { |beats| !beats.empty? }
    end
  end
end

puts "pattern service — round trip"
check("a saved pattern loads back identically") do
  manager.reset_to_defaults
  { "default_kick" => { 0 => true, 4 => true, 8 => true }, "default_snare" => { 4 => true, 12 => true } }.then do |pattern|
    Dir.mktmpdir do |dir|
      File.join(dir, "round-trip.mid").then do |path|
        service.save_pattern(path, pattern, 140)
        service.load_pattern(path).then do |state, bpm|
          bpm.round == 140 &&
            state["default_kick"] == pattern["default_kick"] &&
            state["default_snare"] == pattern["default_snare"]
        end
      end
    end
  end
end

puts "sample loader"
loader = DrumMachine::SampleLoader.new(44_100)
samples = loader.load_samples(manager.all_parts)
check("every bundled sample decodes") { samples.length == 10 }
check("samples are stereo interleaved") { samples.each_value.all? { |data| (data.length % 2).zero? } }
check("samples are in range") { samples["default_kick"].minmax.map(&:abs).max <= 1.0 }
check("a 24-bit mono sample decodes to a sensible length") do
  samples["default_snare"].length.between?(2_000, 4_000_000)
end

puts "renderer and encoder"
check("a pattern renders to a normalised buffer") do
  DrumMachine::AudioRenderer.new(samples, 44_100).render_pattern(
    { "default_kick" => { 0 => true, 8 => true }, "default_snare" => { 4 => true } },
    120,
    16,
    2,
  ).then do |buffer|
    buffer.frame_count.positive? && buffer.buffer.minmax.map(&:abs).max.round(2) == 0.95
  end
end

check("the WAV encoder writes a readable RIFF file") do
  DrumMachine::AudioRenderer.new(samples, 44_100).render_pattern(
    { "default_kick" => { 0 => true, 4 => true } },
    120,
    16,
    1,
  ).then do |buffer|
    Dir.mktmpdir do |dir|
      File.join(dir, "out.wav").then do |path|
        DrumMachine::AudioEncoder.new(DrumMachine::ExportFormatRegistry.new)
                                 .encode_to_file(buffer.buffer, 44_100, path)
        File.binread(path, 4) == "RIFF" && loader.send(:read_wav, path).length == buffer.buffer.length
      end
    end
  end
end

puts
if FAILURES.empty?
  puts "all checks passed"
else
  puts "#{FAILURES.length} failed: #{FAILURES.join(", ")}"
  exit 1
end
