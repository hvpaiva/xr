# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCliIrbTest < ExercismRbTestCase
  def test_cli_irb_loads_solution_file_relative_to_exercise
    with_cli_fake_commands("irb") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")

      code, out, err = run_cli(["irb", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Opening IRB for two-fer"
      assert_command_log log_path, command: "irb", pwd: exercise_dir, args: ["-r", "./two_fer.rb", "--simple-prompt"]
    end
  end

  def test_cli_irb_reports_failed_command
    with_cli_fake_commands("irb") do |_dir, root, state_path, env, _log_path|
      create_exercise(root, "two-fer")
      env = env.merge("XRB_FAKE_EXIT" => "1")

      code, _out, err = run_cli(["irb", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Command failed: irb -r ./two_fer.rb --simple-prompt"
    end
  end
end
