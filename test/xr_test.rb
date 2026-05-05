# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
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

  def test_exercise_finds_test_and_solution_files
    Dir.mktmpdir do |root|
      exercise_dir = File.join(root, "two-fer")
      FileUtils.mkdir_p(exercise_dir)
      File.write(File.join(exercise_dir, "two_fer.rb"), "")
      File.write(File.join(exercise_dir, "two_fer_test.rb"), "")

      exercise = Xr::Exercise.new(slug: "two-fer", root: root)

      assert_equal "two_fer.rb", exercise.solution_file
      assert_equal "two_fer_test.rb", exercise.test_file
    end
  end

  def test_resolver_uses_state_when_not_inside_exercise_root
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      exercise_dir = File.join(root, "assembly-line")
      FileUtils.mkdir_p(exercise_dir)

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
      current_dir = File.join(root, "two-fer")
      state_dir = File.join(root, "assembly-line")
      FileUtils.mkdir_p(current_dir)
      FileUtils.mkdir_p(state_dir)

      state = Xr::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: state_dir)

      resolver = Xr::Resolver.new(state: state, track: "ruby", root: root)

      Dir.chdir(current_dir) do
        assert_equal "two-fer", resolver.resolve.slug
      end
    end
  end
end
