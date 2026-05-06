# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbCliEditorTest < ExercismRbTestCase
  def test_cli_edit_uses_configured_editor
    with_cli_fake_commands("fake-editor") do |_dir, root, state_path, env, log_path|
      exercise_dir = create_exercise(root, "two-fer")
      env = env.merge("XRB_EDITOR" => "fake-editor --wait")

      code, out, err = run_cli(["edit", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Opening two-fer"
      assert_command_log log_path, command: "fake-editor", pwd: exercise_dir, args: ["--wait", "two_fer.rb"]
    end
  end

  def test_cli_edit_reports_missing_editor_command
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(
        ["edit", "two-fer"],
        root: root,
        state_path: state_path,
        extra_env: {"XRB_EDITOR" => "definitely-missing-xrb-editor --wait"}
      )

      assert_equal 1, code
      assert_includes err, "Editor not found: definitely-missing-xrb-editor"
      refute_includes err, "Command failed"
    end
  end

  def test_cli_edit_reports_missing_editor_configuration
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(
        ["edit", "two-fer"],
        root: root,
        state_path: state_path,
        extra_env: {"XRB_EDITOR" => nil, "VISUAL" => nil, "EDITOR" => nil}
      )

      assert_equal 1, code
      assert_includes err, "No editor configured"
      assert_includes err, "XRB_EDITOR"
    end
  end

  def test_cli_edit_reports_invalid_editor_command
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(
        ["edit", "two-fer"],
        root: root,
        state_path: state_path,
        extra_env: {"XRB_EDITOR" => "fake-editor \""}
      )

      assert_equal 1, code
      assert_includes err, "Invalid editor in XRB_EDITOR/VISUAL/EDITOR"
    end
  end

  def test_cli_edit_reports_empty_editor_command
    with_cli_workspace do |_dir, root, state_path|
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(
        ["edit", "two-fer"],
        root: root,
        state_path: state_path,
        extra_env: {"XRB_EDITOR" => ""}
      )

      assert_equal 1, code
      assert_includes err, "No editor configured"
    end
  end

  def test_cli_edit_opens_exercise_directory_when_solution_file_is_missing
    with_cli_fake_commands("fake-editor") do |_dir, root, state_path, env, log_path|
      exercise_dir = File.join(root, "two-fer")
      FileUtils.mkdir_p(exercise_dir)
      File.write(File.join(exercise_dir, "two_fer_test.rb"), "")
      env = env.merge("XRB_EDITOR" => "fake-editor")

      code, out, err = run_cli(["edit", "two-fer"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Opening two-fer"
      assert_command_log log_path, command: "fake-editor", pwd: exercise_dir, args: ["."]
    end
  end

  def test_cli_new_downloads_saves_state_and_opens_editor
    with_cli_fake_commands("exercism", "fake-editor", bodies: {"exercism" => fake_exercism_download_body}) do |_dir, root, state_path, env, log_path|
      env = env.merge("XRB_EDITOR" => "fake-editor")
      code, out, err = run_cli(["new", "assembly-line"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Downloading assembly-line"
      assert_includes out, "Opening assembly-line"
      assert_equal "assembly-line", Exercism::Rb::State.new(path: state_path).load.fetch("exercise")
      assert_command_sequence(
        log_path,
        {command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"]},
        {command: "fake-editor", pwd: File.join(root, "assembly-line"), args: ["assembly_line.rb"]}
      )
    end
  end

  def test_cli_new_can_skip_opening_editor
    with_cli_fake_commands("exercism", bodies: {"exercism" => fake_exercism_download_body}) do |_dir, root, state_path, env, log_path|
      env = env.merge("XRB_EDITOR" => nil, "VISUAL" => nil, "EDITOR" => nil)
      code, out, err = run_cli(["new", "assembly-line", "--no-edit"], root: root, state_path: state_path, extra_env: env)

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Downloading assembly-line"
      refute_includes out, "Opening assembly-line"
      assert_equal "assembly-line", Exercism::Rb::State.new(path: state_path).load.fetch("exercise")
      assert_command_sequence(
        log_path,
        {command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"]}
      )
    end
  end

  def test_cli_new_does_not_save_state_or_open_editor_when_download_fails
    with_cli_fake_commands("exercism", "fake-editor") do |_dir, root, state_path, env, log_path|
      env = env.merge("XRB_EDITOR" => "fake-editor", "XRB_FAKE_EXIT" => "1")
      code, _out, err = run_cli(["new", "assembly-line"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Command failed: exercism download"
      refute File.exist?(state_path)
      assert_command_sequence(
        log_path,
        {command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"]}
      )
    end
  end

  def test_cli_new_does_not_save_state_when_download_does_not_create_expected_directory
    with_cli_fake_commands("exercism", "fake-editor") do |_dir, root, state_path, env, log_path|
      env = env.merge("XRB_EDITOR" => "fake-editor")
      code, _out, err = run_cli(["new", "assembly-line"], root: root, state_path: state_path, extra_env: env)

      assert_equal 1, code
      assert_includes err, "Download completed, but xrb could not find the expected exercise directory"
      assert_includes err, "Exercism CLI probably downloaded to another workspace"
      assert_includes err, "exercism configure --workspace #{File.dirname(root)}"
      refute File.exist?(state_path)
      assert_command_sequence(
        log_path,
        {command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"]}
      )
    end
  end
end
