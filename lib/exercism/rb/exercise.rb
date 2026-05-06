# frozen_string_literal: true

module Exercism
  module Rb
    class Exercise
      SLUG_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/

      attr_reader :slug, :track, :root, :path

      def initialize(slug:, track: Config.track, root: Config.root(track), path: nil)
        slug = slug.to_s.strip
        raise Error, "Exercise is required." if slug.empty?
        raise Error, "Invalid slug: #{slug.inspect}. Use something like assembly-line." unless slug.match?(SLUG_PATTERN)

        @slug = slug
        @track = track
        @root = File.expand_path(root)
        @path = File.expand_path(path || File.join(@root, @slug))
      end

      def exists?
        Dir.exist?(@path)
      end

      def ensure_exists!
        return self if exists?

        raise Error, "Exercise not found: #{@path}"
      end

      def test_file
        ensure_exists!
        pick_one(files_matching { |name| name.end_with?("_test.rb") }, kind: "test file (*_test.rb)")
      end

      def solution_file
        ensure_exists!
        pick_one(files_matching { |name| name.end_with?(".rb") && !name.end_with?("_test.rb") }, kind: "solution file (.rb)")
      end

      private

      def files_matching
        Dir.children(@path)
           .select { |name| File.file?(File.join(@path, name)) && yield(name) }
           .sort
      end

      def pick_one(files, kind:)
        case files.length
        when 0
          raise Error, "Could not find #{kind} in #{@path}"
        when 1
          files.first
        else
          raise Error, "Found more than one #{kind} in #{@path}: #{files.join(', ')}"
        end
      end
    end
  end
end
