require 'flintlock/cli'

module Flintlock
  class Completer
    def self.comp_line
      raw = ENV['COMP_LINE'] || ENV['COMMAND_LINE'] || ""
      results = raw.split
      results << "" if raw =~ /\s+$/
      results
    end

    def self.comp_point
      (ENV['COMP_POINT'] || "0").to_i
    end

    def self.current_word_index
      total = 0
      index = 0
      comp_line.map(&:length).each do |len|
        total += len
        break if total > comp_point
        index += 1
      end
      index - 1
    end

    def self.current_word
      comp_line[current_word_index]
    end

    def self.matching_commands
      Cli.all_commands.keys.select { |x| x =~ /^#{current_word}/ }
    end

    def self.complete
      puts matching_commands.join("\n") if current_word_index < 2
    end
  end
end
