# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCliTest < ExercismRbTestCase
  def test_cli_help_is_english_and_lists_irb
    Dir.mktmpdir do |dir|
      code, out, err = run_cli(["help"], root: dir, state_path: File.join(dir, "state.toml"))

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Usage:"
      assert_includes out, "xrb irb [exercise]"
      assert_includes out, "--no-edit"
      assert_includes out, "run exercise tests"
      refute_match(/[^\x00-\x7F]/, out)
    end
  end

  def test_cli_use_saves_current_exercise
    with_cli_workspace do |_dir, root, state_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["use", "two-fer"], root: root, state_path: state_path)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Current exercise: two-fer"
      assert_equal "two-fer", Exercism::Rb::State.new(path: state_path).load.fetch("exercise")
      assert_equal exercise_dir, Exercism::Rb::State.new(path: state_path).load.fetch("path")
    end
  end

  def test_cli_current_shows_saved_exercise
    with_cli_workspace do |_dir, root, state_path|
      exercise_dir = create_exercise(root, "two-fer")
      Exercism::Rb::State.new(path: state_path).save(track: "ruby", exercise: "two-fer", path: exercise_dir)

      code, out, err = run_cli(["current"], root: root, state_path: state_path)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "two-fer"
      assert_includes out, "Path     #{exercise_dir}"
    end
  end

  def test_cli_path_prints_exercise_path
    with_cli_workspace do |_dir, root, state_path|
      exercise_dir = create_exercise(root, "two-fer")
      Exercism::Rb::State.new(path: state_path).save(track: "ruby", exercise: "two-fer", path: exercise_dir)

      code, out, err = run_cli(["path"], root: root, state_path: state_path)

      assert_equal 0, code
      assert_empty err
      assert_equal "#{exercise_dir}\n", out
    end
  end

  def test_cli_list_marks_current_exercise
    with_cli_workspace do |_dir, root, state_path|
      exercise_dir = create_exercise(root, "two-fer")
      create_exercise(root, "assembly-line")
      Exercism::Rb::State.new(path: state_path).save(track: "ruby", exercise: "two-fer", path: exercise_dir)

      code, out, err = run_cli(["list"], root: root, state_path: state_path)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "  assembly-line"
      assert_includes out, "* two-fer"
    end
  end

  def test_cli_clear_removes_saved_state
    with_cli_workspace do |_dir, root, state_path|
      exercise_dir = create_exercise(root, "two-fer")
      Exercism::Rb::State.new(path: state_path).save(track: "ruby", exercise: "two-fer", path: exercise_dir)

      code, out, err = run_cli(["clear"], root: root, state_path: state_path)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "State cleared"
      refute File.exist?(state_path)
    end
  end

  def test_cli_current_warns_when_saved_directory_is_missing
    with_cli_workspace do |_dir, root, state_path|
      missing_dir = File.join(root, "two-fer")
      Exercism::Rb::State.new(path: state_path).save(track: "ruby", exercise: "two-fer", path: missing_dir)

      code, out, err = run_cli(["current"], root: root, state_path: state_path)

      assert_equal 0, code
      assert_includes out, "two-fer"
      assert_includes err, "The saved directory no longer exists"
    end
  end

  def test_cli_reports_invalid_state_file
    Dir.mktmpdir do |dir|
      state_path = File.join(dir, "state.toml")
      File.write(state_path, "not toml\n")

      code, _out, err = run_cli(["current"], root: dir, state_path: state_path)

      assert_equal 1, code
      assert_includes err, "Invalid state"
    end
  end

  def test_cli_list_reports_missing_root
    Dir.mktmpdir do |dir|
      root = File.join(dir, "missing-root")

      code, _out, err = run_cli(["list"], root: root, state_path: File.join(dir, "state.toml"))

      assert_equal 1, code
      assert_includes err, "Exercise directory not found"
    end
  end

  def test_cli_list_warns_when_root_is_empty
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      FileUtils.mkdir_p(root)

      code, out, err = run_cli(["list"], root: root, state_path: File.join(dir, "state.toml"))

      assert_equal 0, code
      assert_empty out
      assert_includes err, "No exercises downloaded"
    end
  end

  def test_cli_rejects_extra_arguments
    Dir.mktmpdir do |dir|
      code, _out, err = run_cli(["path", "two-fer", "extra"], root: dir, state_path: File.join(dir, "state.toml"))

      assert_equal 1, code
      assert_includes err, "Too many arguments: extra"
    end
  end
end
