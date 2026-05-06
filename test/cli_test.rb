# frozen_string_literal: true

require_relative "test_helper"

class XrCliTest < XrTestCase
  def test_cli_help_is_english_and_lists_irb
    Dir.mktmpdir do |dir|
      code, out, err = run_cli(["help"], root: dir, state_path: File.join(dir, "state.toml"))

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Usage:"
      assert_includes out, "xr irb [exercise]"
      assert_includes out, "run the exercise test file"
      refute_match(/[^\x00-\x7F]/, out)
    end
  end

  def test_cli_use_current_path_list_and_clear
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")
      create_exercise(root, "assembly-line")

      code, out, err = run_cli(["use", "two-fer"], root: root, state_path: state_path)
      assert_equal 0, code
      assert_empty err
      assert_includes out, "Current exercise: two-fer"

      code, out, err = run_cli(["current"], root: root, state_path: state_path)
      assert_equal 0, code
      assert_empty err
      assert_includes out, "two-fer"
      assert_includes out, "path:  #{exercise_dir}"

      code, out, err = run_cli(["path"], root: root, state_path: state_path)
      assert_equal 0, code
      assert_empty err
      assert_equal "#{exercise_dir}\n", out

      code, out, err = run_cli(["list"], root: root, state_path: state_path)
      assert_equal 0, code
      assert_empty err
      assert_includes out, "  assembly-line"
      assert_includes out, "* two-fer"

      code, out, err = run_cli(["clear"], root: root, state_path: state_path)
      assert_equal 0, code
      assert_empty err
      assert_includes out, "State cleared"
      refute File.exist?(state_path)
    end
  end

  def test_cli_current_warns_when_saved_directory_is_missing
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      missing_dir = File.join(root, "two-fer")
      Xr::State.new(path: state_path).save(track: "ruby", exercise: "two-fer", path: missing_dir)

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

  def test_cli_test_runs_minitest_in_exercise_directory
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")

      with_fake_commands("ruby") do |bin_dir, log_path|
        code, out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: fake_env(bin_dir, log_path))

        assert_equal 0, code
        assert_empty err
        assert_includes out, "Testing two-fer"
        assert_command_log log_path, command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "two_fer_test.rb"]
      end
    end
  end

  def test_cli_test_reports_ambiguous_test_files_before_running_ruby
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "extra_test.rb"), "")

      with_fake_commands("ruby") do |bin_dir, log_path|
        code, _out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: fake_env(bin_dir, log_path))

        assert_equal 1, code
        assert_includes err, "Found more than one test file"
        refute File.exist?(log_path)
      end
    end
  end

  def test_cli_test_reports_failed_ruby_command_and_restores_cwd
    original_dir = Dir.pwd

    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")

      with_fake_commands("ruby") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_FAKE_EXIT" => "1")
        code, _out, err = run_cli(["test", "two-fer"], root: root, state_path: state_path, extra_env: env)

        assert_equal 1, code
        assert_includes err, "Command failed: ruby -r minitest/pride two_fer_test.rb"
        assert_equal original_dir, Dir.pwd
        assert_command_log log_path, command: "ruby", pwd: exercise_dir, args: ["-r", "minitest/pride", "two_fer_test.rb"]
      end
    end
  end

  def test_cli_irb_loads_solution_file_relative_to_exercise
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")

      with_fake_commands("irb") do |bin_dir, log_path|
        code, out, err = run_cli(["irb", "two-fer"], root: root, state_path: state_path, extra_env: fake_env(bin_dir, log_path))

        assert_equal 0, code
        assert_empty err
        assert_includes out, "Opening IRB for two-fer"
        assert_command_log log_path, command: "irb", pwd: exercise_dir, args: ["-r", "./two_fer.rb", "--simple-prompt"]
      end
    end
  end

  def test_cli_irb_reports_failed_command
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      create_exercise(root, "two-fer")

      with_fake_commands("irb") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_FAKE_EXIT" => "1")
        code, _out, err = run_cli(["irb", "two-fer"], root: root, state_path: state_path, extra_env: env)

        assert_equal 1, code
        assert_includes err, "Command failed: irb -r ./two_fer.rb --simple-prompt"
      end
    end
  end

  def test_cli_submit_runs_exercism_submit
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")

      with_fake_commands("exercism") do |bin_dir, log_path|
        code, out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: fake_env(bin_dir, log_path))

        assert_equal 0, code
        assert_empty err
        assert_includes out, "Submitting two-fer"
        assert_command_log log_path, command: "exercism", pwd: exercise_dir, args: ["submit", "two_fer.rb"]
      end
    end
  end

  def test_cli_submit_reports_failed_exercism_command
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      create_exercise(root, "two-fer")

      with_fake_commands("exercism") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_FAKE_EXIT" => "1")
        code, _out, err = run_cli(["submit", "two-fer"], root: root, state_path: state_path, extra_env: env)

        assert_equal 1, code
        assert_includes err, "Command failed: exercism submit two_fer.rb"
      end
    end
  end

  def test_cli_edit_uses_configured_editor
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = create_exercise(root, "two-fer")

      with_fake_commands("fake-editor") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_EDITOR" => "fake-editor --wait")
        code, out, err = run_cli(["edit", "two-fer"], root: root, state_path: state_path, extra_env: env)

        assert_equal 0, code
        assert_empty err
        assert_includes out, "Opening two-fer"
        assert_command_log log_path, command: "fake-editor", pwd: exercise_dir, args: ["--wait", "two_fer.rb"]
      end
    end
  end

  def test_cli_edit_reports_invalid_editor_command
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(
        ["edit", "two-fer"],
        root: root,
        state_path: state_path,
        extra_env: { "XR_EDITOR" => "fake-editor \"" }
      )

      assert_equal 1, code
      assert_includes err, "Invalid editor in XR_EDITOR/VISUAL/EDITOR"
    end
  end

  def test_cli_edit_reports_empty_editor_command
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      create_exercise(root, "two-fer")

      code, _out, err = run_cli(
        ["edit", "two-fer"],
        root: root,
        state_path: state_path,
        extra_env: { "XR_EDITOR" => "" }
      )

      assert_equal 1, code
      assert_includes err, "Invalid editor in XR_EDITOR/VISUAL/EDITOR"
    end
  end

  def test_cli_edit_opens_exercise_directory_when_solution_file_is_missing
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercise_dir = File.join(root, "two-fer")
      FileUtils.mkdir_p(exercise_dir)
      File.write(File.join(exercise_dir, "two_fer_test.rb"), "")

      with_fake_commands("fake-editor") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_EDITOR" => "fake-editor")
        code, out, err = run_cli(["edit", "two-fer"], root: root, state_path: state_path, extra_env: env)

        assert_equal 0, code
        assert_empty err
        assert_includes out, "Opening two-fer"
        assert_command_log log_path, command: "fake-editor", pwd: exercise_dir, args: ["."]
      end
    end
  end

  def test_cli_new_downloads_saves_state_and_opens_editor
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")
      exercism_body = <<~'SH'
        if [ "$1" = "download" ]; then
          slug=""
          for arg in "$@"; do
            case "$arg" in
              --exercise=*) slug="${arg#--exercise=}" ;;
            esac
          done
          solution=$(printf '%s' "$slug" | tr '-' '_')
          mkdir -p "$XR_ROOT/$slug"
          : > "$XR_ROOT/$slug/$solution.rb"
          : > "$XR_ROOT/$slug/${solution}_test.rb"
        fi
      SH

      with_fake_commands("exercism", "fake-editor", bodies: { "exercism" => exercism_body }) do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_EDITOR" => "fake-editor")
        code, out, err = run_cli(["new", "assembly-line"], root: root, state_path: state_path, extra_env: env)

        assert_equal 0, code
        assert_empty err
        assert_includes out, "Downloading assembly-line"
        assert_includes out, "Opening assembly-line"
        assert_equal "assembly-line", Xr::State.new(path: state_path).load.fetch("exercise")
        assert_command_sequence(
          log_path,
          { command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"] },
          { command: "fake-editor", pwd: File.join(root, "assembly-line"), args: ["assembly_line.rb"] }
        )
      end
    end
  end

  def test_cli_new_does_not_save_state_or_open_editor_when_download_fails
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")

      with_fake_commands("exercism", "fake-editor") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_EDITOR" => "fake-editor", "XR_FAKE_EXIT" => "1")
        code, _out, err = run_cli(["new", "assembly-line"], root: root, state_path: state_path, extra_env: env)

        assert_equal 1, code
        assert_includes err, "Command failed: exercism download"
        refute File.exist?(state_path)
        assert_command_sequence(
          log_path,
          { command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"] }
        )
      end
    end
  end

  def test_cli_new_does_not_save_state_when_download_does_not_create_expected_directory
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      state_path = File.join(dir, "state.toml")

      with_fake_commands("exercism", "fake-editor") do |bin_dir, log_path|
        env = fake_env(bin_dir, log_path).merge("XR_EDITOR" => "fake-editor")
        code, _out, err = run_cli(["new", "assembly-line"], root: root, state_path: state_path, extra_env: env)

        assert_equal 1, code
        assert_includes err, "Exercise not found"
        refute File.exist?(state_path)
        assert_command_sequence(
          log_path,
          { command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"] }
        )
      end
    end
  end
end
