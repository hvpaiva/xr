# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbSystemTest < ExercismRbTestCase
  def test_bin_version_runs_as_user_invokes_it
    Dir.mktmpdir do |dir|
      code, out, err = run_bin("version", root: dir, state_path: File.join(dir, "state.toml"))

      assert_equal 0, code
      assert_equal "xrb #{Exercism::Rb::VERSION}\n", out
      assert_empty err
    end
  end

  def test_bin_help_runs_as_user_invokes_it
    Dir.mktmpdir do |dir|
      code, out, err = run_bin("help", root: dir, state_path: File.join(dir, "state.toml"))

      assert_equal 0, code
      assert_includes out, "Usage:"
      assert_includes out, "xrb test [exercise]"
      assert_empty err
    end
  end
end
