# frozen_string_literal: true

require_relative "translation"

module DrumMachine
  # NameUtils — ported from upstream's src/utils/name_utils.py.
  module NameUtils
    extend Translatable

    # Display name for a sample file: the basename without its extension, with
    # underscores and hyphens turned into spaces and every word capitalised.
    def self.extract_name_from_path(file_path)
      File.basename(file_path.to_s, ".*").tr("_-", "  ").then do |stem|
        titleize(stem).then { |name| name.strip.empty? ? _("Custom Sound") : name }
      end
    end

    # Python's str.title(): every word's first letter upper-cased, the rest
    # lower-cased. Ruby has no equivalent, so it is spelled out here.
    def self.titleize(text)
      text.split(/(\s+)/).map { |part| part.strip.empty? ? part : part.capitalize }.join
    end
  end
end
