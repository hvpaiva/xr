# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCliIrbTest < ExercismRbTestCase
  def test_cli_irb_loads_solution_file_relative_to_exercise
    with_cli_fake_commands("irb", bodies: {"irb" => console_env_log_body}) do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["irb", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Opening IRB for two-fer"
      assert_command_log log_path, command: "irb", pwd: exercise_dir, args: ["-r", "exercism/rb/console_bootstrap", "--simple-prompt"]
      assert_console_env_log log_path, solution_file: "two_fer.rb"
    end
  end

  def test_cli_pry_loads_same_console_bootstrap
    with_cli_fake_commands("pry", bodies: {"pry" => console_env_log_body}) do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["pry", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Opening Pry for two-fer"
      assert_command_log log_path, command: "pry", pwd: exercise_dir, args: ["-r", "exercism/rb/console_bootstrap", "--simple-prompt"]
      assert_console_env_log log_path, solution_file: "two_fer.rb"
    end
  end

  def test_cli_irb_reports_failed_command
    with_cli_fake_commands("irb") do |_dir, root, state_path, env, _log_path|
      create_exercise(root, "two-fer")
      env = env.merge("XRB_FAKE_EXIT" => "1")

      code, _out, err = run_cli(["irb", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Command failed: irb -r exercism/rb/console_bootstrap --simple-prompt"
    end
  end

  def test_cli_pry_reports_missing_pry_command_with_install_hint
    with_cli_workspace do |dir, root, state_path|
      empty_bin = File.join(dir, "empty-bin")
      FileUtils.mkdir_p(empty_bin)
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(["pry", "two-fer"], root: root, state_path: state_path, extra_env: {"PATH" => empty_bin})

      assert_equal 1, code
      assert_includes err, "Pry not found"
      assert_includes err, "gem install pry"
    end
  end

  private

  def console_env_log_body
    <<~SH
      printf 'solution=%s\n' "$XRB_CONSOLE_SOLUTION_FILE" >> "$XRB_COMMAND_LOG"
      printf 'rubylib=%s\n' "$RUBYLIB" >> "$XRB_COMMAND_LOG"
    SH
  end

  def assert_console_env_log(log_path, solution_file:)
    log = File.read(log_path)
    assert_includes log, "solution=#{solution_file}\n"
    assert_includes log, "rubylib=#{File.join(PROJECT_ROOT, "lib")}"
  end
end
