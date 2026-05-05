# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require_relative "../lib/xr"

class XrTest < Minitest::Test
  def test_state_is_saved_as_flat_toml
    Dir.mktmpdir do |dir|
      state = Xr::State.new(path: File.join(dir, "state.toml"))

      state.save(track: "ruby", exercise: "two-fer", path: File.join(dir, "two-fer"))

      contents = File.read(state.path)
      assert_includes contents, %(track = "ruby")
      assert_includes contents, %(exercise = "two-fer")
      assert_equal "two-fer", state.load.fetch("exercise")
      assert_equal File.join(dir, "two-fer"), state.load.fetch("path")
    end
  end

  def test_state_parses_escaped_values_and_ignores_unknown_keys
    Dir.mktmpdir do |dir|
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, %(track = "ruby"\nexercise = "two-fer"\nignored = "value"\npath = "a\\nb"\n))

      data = state.load

      assert_equal "ruby", data.fetch("track")
      assert_equal "two-fer", data.fetch("exercise")
      assert_equal "a\nb", data.fetch("path")
      refute_includes data.keys, "ignored"
    end
  end

  def test_state_reports_invalid_toml_line
    Dir.mktmpdir do |dir|
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, "not toml\n")

      error = assert_raises(Xr::Error) { state.load }

      assert_includes error.message, "Invalid state"
      assert_includes error.message, "line 1"
    end
  end

  def test_state_reports_unterminated_quoted_value
    Dir.mktmpdir do |dir|
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, "track = \"ruby\n")

      error = assert_raises(Xr::Error) { state.load }

      assert_includes error.message, "Invalid quoted value"
    end
  end

  def test_state_clear_removes_saved_state
    Dir.mktmpdir do |dir|
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "two-fer", path: File.join(dir, "two-fer"))

      state.clear

      refute File.exist?(state.path)
    end
  end

  def test_exercise_requires_valid_slug
    assert_raises_with_message(Xr::Error, "Exercise is required") do
      Xr::Exercise.new(slug: " ")
    end

    assert_raises_with_message(Xr::Error, "Invalid slug") do
      Xr::Exercise.new(slug: "Two Fer")
    end
  end

  def test_exercise_requires_existing_directory
    Dir.mktmpdir do |root|
      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      assert_raises_with_message(Xr::Error, "Exercise not found") do
        exercise.ensure_exists!
      end
    end
  end

  def test_exercise_finds_test_and_solution_files
    Dir.mktmpdir do |root|
      create_exercise(root, "two-fer")

      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      assert_equal "two_fer.rb", exercise.solution_file
      assert_equal "two_fer_test.rb", exercise.test_file
    end
  end

  def test_exercise_reports_missing_solution_file
    Dir.mktmpdir do |root|
      exercise_dir = File.join(root, "two-fer")
      FileUtils.mkdir_p(exercise_dir)
      File.write(File.join(exercise_dir, "two_fer_test.rb"), "")
      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      error = assert_raises(Xr::Error) { exercise.solution_file }

      assert_includes error.message, "Could not find solution file"
    end
  end

  def test_exercise_reports_missing_test_file
    Dir.mktmpdir do |root|
      exercise_dir = File.join(root, "two-fer")
      FileUtils.mkdir_p(exercise_dir)
      File.write(File.join(exercise_dir, "two_fer.rb"), "")
      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      error = assert_raises(Xr::Error) { exercise.test_file }

      assert_includes error.message, "Could not find test file"
    end
  end

  def test_exercise_reports_ambiguous_solution_files
    Dir.mktmpdir do |root|
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "alternate.rb"), "")
      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      error = assert_raises(Xr::Error) { exercise.solution_file }

      assert_includes error.message, "Found more than one solution file"
      assert_includes error.message, "alternate.rb"
    end
  end

  def test_exercise_reports_ambiguous_test_files
    Dir.mktmpdir do |root|
      exercise_dir = create_exercise(root, "two-fer")
      File.write(File.join(exercise_dir, "extra_test.rb"), "")
      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      error = assert_raises(Xr::Error) { exercise.test_file }

      assert_includes error.message, "Found more than one test file"
      assert_includes error.message, "extra_test.rb"
    end
  end

  def test_resolver_uses_explicit_slug_first
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      explicit_dir = create_exercise(root, "two-fer")
      state_dir = create_exercise(root, "assembly-line")
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: state_dir)

      resolver = Xr::Resolver.new(state: state, track: "ruby", root: root)
      exercise = resolver.resolve("two-fer")

      assert_equal "two-fer", exercise.slug
      assert_equal explicit_dir, exercise.path
    end
  end

  def test_resolver_uses_state_when_not_inside_exercise_root
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      exercise_dir = create_exercise(root, "assembly-line")
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: exercise_dir)

      resolver = Xr::Resolver.new(state: state, track: "ruby", root: root)
      exercise = resolver.resolve

      assert_equal "assembly-line", exercise.slug
      assert_equal exercise_dir, exercise.path
    end
  end

  def test_resolver_prefers_current_exercise_directory_over_state
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      current_dir = create_exercise(root, "two-fer")
      state_dir = create_exercise(root, "assembly-line")
      state = Xr::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: state_dir)

      resolver = Xr::Resolver.new(state: state, track: "ruby", root: root)
      nested_dir = File.join(current_dir, "nested")
      FileUtils.mkdir_p(nested_dir)

      Dir.chdir(nested_dir) do
        assert_equal "two-fer", resolver.resolve.slug
      end
    end
  end

  def test_resolver_reports_missing_current_exercise
    Dir.mktmpdir do |dir|
      resolver = Xr::Resolver.new(state: Xr::State.new(path: File.join(dir, "state.toml")), root: dir)

      error = assert_raises(Xr::Error) { resolver.resolve }

      assert_includes error.message, "No current exercise"
    end
  end

  def test_cli_help_is_english_and_lists_irb
    Dir.mktmpdir do |dir|
      code, out, err = run_cli(["help"], root: dir, state_path: File.join(dir, "state.toml"))

      assert_equal 0, code
      assert_empty err
      assert_includes out, "Usage:"
      assert_includes out, "xr irb [exercise]"
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
        assert_command_log log_path, command: "exercism", pwd: Dir.pwd, args: ["download", "--track=ruby", "--exercise=assembly-line"]
        assert_command_log log_path, command: "fake-editor", pwd: File.join(root, "assembly-line"), args: ["assembly_line.rb"]
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
        refute_includes File.read(log_path), "command=fake-editor"
      end
    end
  end

  private

  def assert_raises_with_message(error_class, expected_message)
    error = assert_raises(error_class) { yield }

    assert_includes error.message, expected_message
  end

  def create_exercise(root, slug)
    exercise_dir = File.join(root, slug)
    basename = slug.tr("-", "_")
    FileUtils.mkdir_p(exercise_dir)
    File.write(File.join(exercise_dir, "#{basename}.rb"), "")
    File.write(File.join(exercise_dir, "#{basename}_test.rb"), "")
    exercise_dir
  end

  def run_cli(argv, root:, state_path:, extra_env: {})
    out = StringIO.new
    err = StringIO.new
    env = {
      "XR_ROOT" => root,
      "XR_STATE" => state_path,
      "XR_TRACK" => "ruby"
    }.merge(extra_env)

    code = with_env(env) { Xr::CLI.start(argv, out: out, err: err) }

    [code, out.string, err.string]
  end

  def with_fake_commands(*names, bodies: {})
    Dir.mktmpdir do |bin_dir|
      log_path = File.join(bin_dir, "commands.log")
      names.each do |name|
        write_fake_command(bin_dir, name, body: bodies.fetch(name, ""))
      end

      yield bin_dir, log_path
    end
  end

  def fake_env(bin_dir, log_path)
    {
      "PATH" => "#{bin_dir}:#{ENV.fetch('PATH')}",
      "XR_COMMAND_LOG" => log_path
    }
  end

  def write_fake_command(bin_dir, name, body: "")
    path = File.join(bin_dir, name)
    File.write(path, <<~SH)
      #!/usr/bin/env sh
      {
        printf 'command=%s\n' '#{name}'
        printf 'pwd=%s\n' "$PWD"
        printf 'args='
        for arg in "$@"; do
          printf '[%s]' "$arg"
        done
        printf '\n'
      } >> "$XR_COMMAND_LOG"
      #{body}
      exit "${XR_FAKE_EXIT:-0}"
    SH
    File.chmod(0o755, path)
  end

  def assert_command_log(log_path, command:, pwd:, args:)
    expected = "command=#{command}\npwd=#{pwd}\nargs=#{args.map { |arg| "[#{arg}]" }.join}\n"

    assert_includes File.read(log_path), expected
  end

  def with_env(values)
    missing = Object.new
    old = {}

    values.each do |key, value|
      old[key] = ENV.key?(key) ? ENV[key] : missing
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    old.each do |key, value|
      value.equal?(missing) ? ENV.delete(key) : ENV[key] = value
    end
  end
end
