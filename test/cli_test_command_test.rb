# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCliTestCommandTest < ExercismRbTestCase
  def test_cli_test_runs_minitest_in_exercise_directory
    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Testing two-fer"
      assert_command_log log_path, command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "two_fer_test.rb"]
    end
  end

  def test_cli_test_uses_configured_test_file
    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer", test_files: ["custom_test.rb"], config: true)

      code, out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Testing two-fer"
      assert_command_log log_path, command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "custom_test.rb"]
    end
  end

  def test_cli_test_runs_multiple_configured_test_files
    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer", test_files: ["two_fer_test.rb", "extra_test.rb"], config: true)

      code, out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Testing two-fer"
      assert_command_sequence(
        log_path,
        {command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "two_fer_test.rb"]},
        {command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "extra_test.rb"]}
      )
    end
  end

  def test_cli_test_uses_explicit_file_option
    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer", test_files: ["two_fer_test.rb", "custom_test.rb"], config: true)

      code, out, err = run_cli(["test", "two-fer", "--file", "custom_test.rb"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Testing two-fer"
      assert_command_sequence(
        log_path,
        {command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "custom_test.rb"]}
      )
    end
  end

  def test_cli_test_uses_multiple_explicit_file_options
    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "extra_test.rb"), "")

      code, _out, err = run_cli(["test", "--file=two_fer_test.rb", "--file", "extra_test.rb", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_command_sequence(
        log_path,
        {command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "two_fer_test.rb"]},
        {command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "extra_test.rb"]}
      )
    end
  end

  def test_cli_test_reports_ambiguous_test_files_before_running_ruby
    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "extra_test.rb"), "")

      code, _out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Found more than one test file"
      assert_includes err, "--file"
      refute File.exist?(log_path)
    end
  end

  def test_cli_test_reports_missing_file_option_value
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(["test", "two-fer", "--file"], root: root, state_path: state_path)

      assert_equal 1, code
      assert_includes err, "Missing value for --file"
    end
  end

  def test_cli_test_reports_missing_ruby_command
    with_cli_workspace do |dir, root, state_path|
      empty_bin = File.join(dir, "empty-bin")
      FileUtils.mkdir_p(empty_bin)
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: {"PATH" => empty_bin})

      assert_equal 1, code
      assert_includes err, "Command not found: ruby"
    end
  end

  def test_cli_test_reports_failed_ruby_command_and_restores_cwd
    original_dir = Dir.pwd

    with_cli_fake_commands("ruby") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")
      env = env.merge("XRB_FAKE_EXIT" => "1")

      code, _out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Command failed: ruby -r minitest/pride two_fer_test.rb"
      assert_equal original_dir, Dir.pwd
      assert_command_log log_path, command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "two_fer_test.rb"]
    end
  end
end
