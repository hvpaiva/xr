# frozen_string_literal: true

module Xr
  module Config
    module_function

    def track
      ENV.fetch("XR_TRACK", "ruby")
    end

    def root(track_name = track)
      File.expand_path(ENV.fetch("XR_ROOT", File.join(Dir.home, "exercism", track_name)))
    end

    def state_path
      File.expand_path(ENV.fetch("XR_STATE", File.join(Dir.home, ".local", "state", "xr", "state.toml")))
    end

    def editor
      ENV["XR_EDITOR"] || ENV["VISUAL"] || ENV["EDITOR"] || "nvim"
    end
  end
end
