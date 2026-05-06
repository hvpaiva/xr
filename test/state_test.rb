# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbStateTest < ExercismRbTestCase
  def test_state_load_returns_empty_hash_when_file_is_missing
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))

      assert_equal({}, state.load)
    end
  end

  def test_state_is_saved_as_flat_toml
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))

      state.save(track: "ruby", exercise: "two-fer", path: File.join(dir, "two-fer"))

      contents = File.read(state.path)
      assert_includes contents, %(track = "ruby")
      assert_includes contents, %(exercise = "two-fer")
      assert_equal "two-fer", state.load.fetch("exercise")
      assert_equal File.join(dir, "two-fer"), state.load.fetch("path")
    end
  end

  def test_state_save_does_not_emit_warnings
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      stderr = StringIO.new
      original_stderr = $stderr
      original_verbose = $VERBOSE

      $stderr = stderr
      $VERBOSE = true
      state.save(track: "ruby", exercise: "two-fer", path: File.join(dir, "two-fer"))

      assert_empty stderr.string
    ensure
      $stderr = original_stderr
      $VERBOSE = original_verbose
    end
  end

  def test_state_parses_escaped_values_and_ignores_unknown_keys
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, %(track = "ruby"\nexercise = "two-fer"\nignored = "value"\npath = "a\\nb"\n))

      data = state.load

      assert_equal "ruby", data.fetch("track")
      assert_equal "two-fer", data.fetch("exercise")
      assert_equal "a\nb", data.fetch("path")
      refute_includes data.keys, "ignored"
    end
  end

  def test_state_parses_comments_blank_lines_and_unquoted_values
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, "# comment\n\ntrack = ruby\nexercise = two-fer\n")

      data = state.load

      assert_equal "ruby", data.fetch("track")
      assert_equal "two-fer", data.fetch("exercise")
    end
  end

  def test_state_parses_supported_quoted_escapes
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, %(path = "a\\rb\\tc\\\\d\\"e"\n))

      assert_equal "a\rb\tc\\d\"e", state.load.fetch("path")
    end
  end

  def test_state_reports_invalid_toml_line
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, "not toml\n")

      error = assert_raises(Exercism::Rb::Error) { state.load }

      assert_includes error.message, "Invalid state"
      assert_includes error.message, "line 1"
    end
  end

  def test_state_reports_unterminated_quoted_value
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      File.write(state.path, "track = \"ruby\n")

      error = assert_raises(Exercism::Rb::Error) { state.load }

      assert_includes error.message, "Invalid quoted value"
    end
  end

  def test_state_clear_removes_saved_state
    Dir.mktmpdir do |dir|
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "two-fer", path: File.join(dir, "two-fer"))

      state.clear

      refute File.exist?(state.path)
    end
  end
end
