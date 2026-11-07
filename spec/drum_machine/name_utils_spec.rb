# frozen_string_literal: true

RSpec.describe DrumMachine::NameUtils do
  describe ".extract_name_from_path" do
    it "titleizes a snake_case basename" do
      expect(described_class.extract_name_from_path("/x/kick_drum.wav")).to eq("Kick Drum")
    end

    it "titleizes a hyphenated basename" do
      expect(described_class.extract_name_from_path("/x/hi-hat-2.wav")).to eq("Hi Hat 2")
    end

    it "strips the extension only, not interior dots" do
      expect(described_class.extract_name_from_path("snare.tail.wav")).to eq("Snare.tail")
    end

    it "falls back when the basename has nothing left to show" do
      expect(described_class.extract_name_from_path("___.wav")).to eq("Custom Sound")
    end
  end

  describe ".titleize" do
    it "capitalises each word and lower-cases the rest" do
      expect(described_class.titleize("HELLO world")).to eq("Hello World")
    end

    it "preserves internal whitespace runs" do
      expect(described_class.titleize("a  b")).to eq("A  B")
    end
  end
end
