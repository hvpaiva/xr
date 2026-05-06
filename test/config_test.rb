# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbConfigTest < ExercismRbTestCase
  def test_config_uses_default_values
    with_env(default_config_env) do
      assert_equal "ruby", Exercism::Rb::Config.track
      assert_equal File.expand_path(File.join(Dir.home, "exercism", "ruby")), Exercism::Rb::Config.root
      assert_equal File.expand_path(File.join(Dir.home, ".local", "state", "exercism-rb", "state.toml")), Exercism::Rb::Config.state_path
      assert_nil Exercism::Rb::Config.editor
    end
  end

  def test_config_uses_environment_overrides
    Dir.mktmpdir do |dir|
      root = File.join(dir, "custom-root")
      state_path = File.join(dir, "state.toml")

      with_env(default_config_env.merge("XRB_TRACK" => "go", "XRB_ROOT" => root, "XRB_STATE" => state_path, "XRB_EDITOR" => "code --wait")) do
        assert_equal "go", Exercism::Rb::Config.track
        assert_equal File.expand_path(root), Exercism::Rb::Config.root
        assert_equal File.expand_path(state_path), Exercism::Rb::Config.state_path
        assert_equal "code --wait", Exercism::Rb::Config.editor
      end
    end
  end

  def test_config_defaults_root_to_selected_track
    with_env(default_config_env.merge("XRB_TRACK" => "python")) do
      assert_equal File.expand_path(File.join(Dir.home, "exercism", "python")), Exercism::Rb::Config.root
    end
  end

  def test_config_editor_falls_back_to_visual_then_editor
    with_env(default_config_env.merge("VISUAL" => "zed --wait", "EDITOR" => "vim")) do
      assert_equal "zed --wait", Exercism::Rb::Config.editor
    end

    with_env(default_config_env.merge("EDITOR" => "vim")) do
      assert_equal "vim", Exercism::Rb::Config.editor
    end
  end

  private

  def default_config_env
    {
      "XRB_TRACK" => nil,
      "XRB_ROOT" => nil,
      "XRB_STATE" => nil,
      "XRB_EDITOR" => nil,
      "VISUAL" => nil,
      "EDITOR" => nil
    }
  end
end
