# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCommandRunnerTest < ExercismRbTestCase
  def test_command_runner_runs_successful_command_in_requested_directory
    runner = command_runner

    Dir.mktmpdir do |dir|
      with_fake_commands("ok-command") do |bin_dir, log_path|
        with_env(fake_env(bin_dir, log_path)) do
          runner.run("ok-command", "arg", chdir: dir)
        end

        assert_command_log log_path, command: "ok-command", pwd: dir, args: ["arg"]
      end
    end
  end

  def test_command_runner_reports_missing_command
    runner = command_runner

    error = assert_raises(Exercism::Rb::Error) do
      runner.run("definitely-missing-xrb-command")
    end

    assert_includes error.message, "Command not found: definitely-missing-xrb-command"
  end

  def test_command_runner_preserves_failed_command_message
    runner = command_runner

    with_fake_commands("fail-command") do |bin_dir, log_path|
      with_env(fake_env(bin_dir, log_path).merge("XRB_FAKE_EXIT" => "1")) do
        error = assert_raises(Exercism::Rb::Error) do
          runner.run("fail-command", "arg")
        end

        assert_includes error.message, "Command failed: fail-command arg"
      end
    end
  end

  private

  def command_runner
    out = StringIO.new
    err = StringIO.new
    ui = Exercism::Rb::UI.new(out: out, err: err, color: false)

    Exercism::Rb::CommandRunner.new(ui: ui)
  end
end
