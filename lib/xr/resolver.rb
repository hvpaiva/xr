# frozen_string_literal: true

module Xr
  class Resolver
    def initialize(state:, track: Config.track, root: Config.root(track))
      @state = state
      @track = track
      @root = File.expand_path(root)
    end

    def resolve(slug = nil, require_existing: true)
      exercise = if present?(slug)
                   Exercise.new(slug: slug, track: @track, root: @root)
                 else
                   from_current_directory || from_state
                 end

      exercise.ensure_exists! if require_existing
      exercise
    end

    private

    def from_current_directory
      cwd = File.expand_path(Dir.pwd)
      root_with_separator = @root.end_with?(File::SEPARATOR) ? @root : "#{@root}#{File::SEPARATOR}"
      return nil unless cwd.start_with?(root_with_separator)

      relative = cwd.delete_prefix(root_with_separator)
      slug = relative.split(File::SEPARATOR).first
      return nil unless present?(slug)

      Exercise.new(slug: slug, track: @track, root: @root)
    end

    def from_state
      data = @state.load
      slug = data["exercise"]
      raise Error, "No current exercise. Use `xr new <exercise>` or `xr use <exercise>`." unless present?(slug)

      Exercise.new(
        slug: slug,
        track: data["track"] || @track,
        root: File.dirname(data["path"] || File.join(@root, slug)),
        path: data["path"]
      )
    end

    def present?(value)
      !value.nil? && !value.to_s.strip.empty?
    end
  end
end
