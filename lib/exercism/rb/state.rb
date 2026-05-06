# frozen_string_literal: true

require "fileutils"
require "time"

module Exercism
  module Rb
    class State
      KEYS = %w[track exercise path updated_at].freeze

      attr_reader :path

      def initialize(path: Config.state_path)
        @path = File.expand_path(path)
      end

      def load
        return {} unless File.file?(@path)

        parse(File.read(@path))
      end

      def save(track:, exercise:, path:)
        data = {
          "track" => track,
          "exercise" => exercise,
          "path" => File.expand_path(path),
          "updated_at" => Time.now.utc.iso8601
        }

        FileUtils.mkdir_p(File.dirname(@path))
        tmp_path = "#{@path}.tmp.#{$PROCESS_ID}"
        File.write(tmp_path, to_toml(data))
        File.rename(tmp_path, @path)
        data
      end

      def clear
        File.delete(@path) if File.file?(@path)
      end

      private

      def parse(content)
        data = {}

        content.each_line.with_index(1) do |line, number|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("#")

          match = stripped.match(/\A([A-Za-z0-9_-]+)\s*=\s*(.+)\z/)
          raise Error, "Invalid state in #{@path}: line #{number}" unless match

          key = match[1]
          next unless KEYS.include?(key)

          data[key] = parse_value(match[2].strip)
        end

        data
      end

      def parse_value(raw)
        quoted_start = raw.start_with?("\"")
        quoted_end = raw.end_with?("\"")
        raise Error, "Invalid quoted value in #{@path}" if quoted_start != quoted_end

        return unquote(raw) if raw.start_with?("\"") && raw.end_with?("\"")

        raw
      end

      def unquote(raw)
        value = raw[1...-1]
        value.gsub(/\\(["\\nrt])/) do
          case Regexp.last_match(1)
          when '"' then '"'
          when "\\" then "\\"
          when "n" then "\n"
          when "r" then "\r"
          when "t" then "\t"
          end
        end
      end

      def to_toml(data)
        KEYS.filter_map do |key|
          next unless data.key?(key)

          "#{key} = #{quote(data.fetch(key))}"
        end.join("\n") + "\n"
      end

      def quote(value)
        escaped = value.to_s
                       .gsub("\\", "\\\\")
                       .gsub('"', '\\"')
                       .gsub("\n", "\\n")
                       .gsub("\r", "\\r")
                       .gsub("\t", "\\t")

        %("#{escaped}")
      end
    end
  end
end
