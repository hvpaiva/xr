# frozen_string_literal: true

require "json"

module Exercism
  module Rb
    class Exercise
      SLUG_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/
      FILE_KINDS = {
        "test" => {config: "test file", fallback: "test file (*_test.rb)"},
        "solution" => {config: "solution file", fallback: "solution file (.rb)"}
      }.freeze

      attr_reader :slug, :track, :root, :path

      def initialize(slug:, track: Config.track, root: Config.root(track), path: nil)
        slug = slug.to_s.strip
        raise Error, "Exercise is required." if slug.empty?
        raise Error, "Invalid slug: #{slug.inspect}. Use something like assembly-line." unless slug.match?(SLUG_PATTERN)

        @slug = slug
        @track = track
        @root = File.expand_path(root)
        @path = File.expand_path(path || File.join(@root, @slug))
        @exercism_config = nil
      end

      def exists?
        Dir.exist?(@path)
      end

      def ensure_exists!
        return self if exists?

        raise Error, "Exercise not found: #{@path}"
      end

      def exercism_config?
        File.file?(config_path)
      end

      def test_files(ambiguity_hint: nil)
        exercise_files("test", ambiguity_hint: ambiguity_hint) do
          fallback_test_files
        end
      end

      def solution_files(ambiguity_hint: nil)
        exercise_files("solution", ambiguity_hint: ambiguity_hint) do
          fallback_solution_files
        end
      end

      def test_file(ambiguity_hint: nil)
        pick_one(test_files(ambiguity_hint: ambiguity_hint), kind: "test file (*_test.rb)", ambiguity_hint: ambiguity_hint)
      end

      def solution_file(ambiguity_hint: nil)
        pick_one(solution_files(ambiguity_hint: ambiguity_hint), kind: "solution file (.rb)", ambiguity_hint: ambiguity_hint)
      end

      private

      def config_path
        File.join(@path, ".exercism", "config.json")
      end

      def exercise_files(config_name, ambiguity_hint:)
        ensure_exists!

        kinds = FILE_KINDS.fetch(config_name)
        configured_files(config_name, kind: kinds.fetch(:config)) || [pick_one(yield, kind: kinds.fetch(:fallback), ambiguity_hint: ambiguity_hint)]
      end

      def exercism_config
        return nil unless exercism_config?
        return @exercism_config unless @exercism_config.nil?

        config = JSON.parse(File.read(config_path))
        raise_invalid_config("root must be an object") unless config.is_a?(Hash)

        @exercism_config = config
      rescue JSON::ParserError => error
        raise Error, "Invalid Exercism config: #{config_path}: #{error.message}"
      end

      def configured_files(name, kind:)
        config = exercism_config
        return nil if config.nil?

        values = configured_file_values(config, name)
        return nil if values.nil?

        ensure_configured_files_exist(values, kind: kind)
      end

      def configured_file_values(config, name)
        files = config.fetch("files", nil)
        return nil if files.nil?
        raise_invalid_config("files must be an object") unless files.is_a?(Hash)
        return nil unless files.key?(name)

        values = files.fetch(name)
        validate_configured_file_list(name, values)
      end

      def validate_configured_file_list(name, values)
        raise_invalid_config("files.#{name} must be an array") unless values.is_a?(Array)
        raise_invalid_config("files.#{name} must not be empty") if values.empty?

        values.each do |file|
          raise_invalid_config("files.#{name} contains an empty path") unless file.is_a?(String) && !file.strip.empty?
        end

        values
      end

      def ensure_configured_files_exist(files, kind:)
        files.each do |file|
          next if File.file?(File.absolute_path(file, @path))

          raise Error, "Configured #{kind} not found: #{file}"
        end

        files
      end

      def raise_invalid_config(message)
        raise Error, "Invalid Exercism config: #{config_path}: #{message}"
      end

      def fallback_test_files
        files_matching { |name| name.end_with?("_test.rb") }
      end

      def fallback_solution_files
        files_matching { |name| name.end_with?(".rb") && !name.end_with?("_test.rb") }
      end

      def files_matching
        Dir.children(@path)
          .select { |name| File.file?(File.join(@path, name)) && yield(name) }
          .sort
      end

      def pick_one(files, kind:, ambiguity_hint: nil)
        case files.length
        when 0
          raise Error, "Could not find #{kind} in #{@path}"
        when 1
          files.first
        else
          message = "Found more than one #{kind} in #{@path}: #{files.join(", ")}"
          message = "#{message}. #{ambiguity_hint}" if ambiguity_hint
          raise Error, message
        end
      end
    end
  end
end
