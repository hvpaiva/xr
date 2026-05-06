# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCliSubmitTest < ExercismRbTestCase
  def test_cli_submit_runs_exercism_submit
    with_cli_fake_commands("exercism") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Submitting two-fer"
      assert_command_log log_path, command: "exercism", pwd: exercise_dir, args: ["submit", "two_fer.rb"]
    end
  end

  def test_cli_submit_delegates_default_files_to_exercism_when_config_exists
    with_cli_fake_commands("exercism") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer", solution_files: ["two_fer.rb", "helper.rb"], config: true)

      code, out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Submitting two-fer"
      assert_command_log log_path, command: "exercism", pwd: exercise_dir, args: ["submit"]
    end
  end

  def test_cli_submit_reports_ambiguous_solution_files_without_config
    with_cli_fake_commands("exercism") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "helper.rb"), "")

      code, _out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Found more than one solution file"
      assert_includes err, "--file"
      refute File.exist?(log_path)
    end
  end

  def test_cli_submit_uses_explicit_file_option
    with_cli_fake_commands("exercism") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["submit", "--file=two_fer.rb", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Submitting two-fer"
      assert_command_log log_path, command: "exercism", pwd: exercise_dir, args: ["submit", "two_fer.rb"]
    end
  end

  def test_cli_submit_uses_multiple_explicit_file_options
    with_cli_fake_commands("exercism") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "helper.rb"), "")

      code, out, err = run_cli(["submit", "two-fer", "--file", "two_fer.rb", "--file", "helper.rb"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Submitting two-fer"
      assert_command_log log_path, command: "exercism", pwd: exercise_dir, args: ["submit", "two_fer.rb", "helper.rb"]
    end
  end

  def test_cli_submit_reports_missing_file_option_value
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(["submit", "--file="], root: root, state_path: state_path)

      assert_equal 1, code
      assert_includes err, "Missing value for --file"
    end
  end

  def test_cli_submit_reports_missing_file_option_value_when_flag_has_no_argument
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(["submit", "two-fer", "--file"], root: root, state_path: state_path)

      assert_equal 1, code
      assert_includes err, "Missing value for --file"
    end
  end

  def test_cli_submit_reports_missing_exercism_command
    with_cli_workspace do |dir, root, state_path|
      empty_bin = File.join(dir, "empty-bin")
      FileUtils.mkdir_p(empty_bin)
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: {"PATH" => empty_bin})

      assert_equal 1, code
      assert_includes err, "Command not found: exercism"
    end
  end

  def test_cli_submit_reports_failed_exercism_command
    with_cli_fake_commands("exercism") do |_dir, root, state_path, env, _log_path|
      create_exercise(root, "two-fer")
      env = env.merge("XRB_FAKE_EXIT" => "1")

      code, _out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Command failed: exercism submit two_fer.rb"
    end
  end
end
