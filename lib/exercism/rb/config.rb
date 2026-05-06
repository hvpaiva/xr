# frozen_string_literal: true

module Exercism
  module Rb
    module Config
      module_function

      def track
        ENV.fetch("XRB_TRACK", "ruby")
      end

      def root(track_name = track)
        File.expand_path(ENV.fetch("XRB_ROOT", File.join(Dir.home, "exercism", track_name)))
      end

      def state_path
        File.expand_path(ENV.fetch("XRB_STATE", File.join(Dir.home, ".local", "state", "exercism-rb", "state.toml")))
      end

      def editor
        ENV["XRB_EDITOR"] || ENV["VISUAL"] || ENV["EDITOR"] || "nvim"
      end
    end
  end
end
