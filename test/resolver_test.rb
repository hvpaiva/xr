# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbResolverTest < ExercismRbTestCase
  def test_resolver_can_return_missing_explicit_exercise_when_existing_directory_is_not_required
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      resolver = Exercism::Rb::Resolver.new(state: Exercism::Rb::State.new(path: File.join(dir, "state.toml")), root: root)

      exercise = resolver.resolve("two-fer", require_existing: false)

      assert_equal "two-fer", exercise.slug
      assert_equal File.join(root, "two-fer"), exercise.path
    end
  end

  def test_resolver_uses_explicit_slug_first
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      explicit_dir = create_exercise(root, "two-fer")
      state_dir = create_exercise(root, "assembly-line")
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: state_dir)

      resolver = Exercism::Rb::Resolver.new(state: state, track: "ruby", root: root)
      exercise = resolver.resolve("two-fer")

      assert_equal "two-fer", exercise.slug
      assert_equal explicit_dir, exercise.path
    end
  end

  def test_resolver_uses_state_when_not_inside_exercise_root
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      exercise_dir = create_exercise(root, "assembly-line")
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: exercise_dir)

      resolver = Exercism::Rb::Resolver.new(state: state, track: "ruby", root: root)
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
      state = Exercism::Rb::State.new(path: File.join(dir, "state.toml"))
      state.save(track: "ruby", exercise: "assembly-line", path: state_dir)

      resolver = Exercism::Rb::Resolver.new(state: state, track: "ruby", root: root)
      nested_dir = File.join(current_dir, "nested")
      FileUtils.mkdir_p(nested_dir)

      Dir.chdir(nested_dir) do
        assert_equal "two-fer", resolver.resolve.slug
      end
    end
  end

  def test_resolver_does_not_treat_similar_root_prefix_as_current_exercise_directory
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      similar_root = File.join(dir, "exercism", "ruby-extra")
      FileUtils.mkdir_p(File.join(similar_root, "two-fer"))
      resolver = Exercism::Rb::Resolver.new(state: Exercism::Rb::State.new(path: File.join(dir, "state.toml")), root: root)

      Dir.chdir(File.join(similar_root, "two-fer")) do
        error = assert_raises(Exercism::Rb::Error) { resolver.resolve }

        assert_includes error.message, "No current exercise"
      end
    end
  end

  def test_resolver_uses_default_root_when_state_has_no_path
    Dir.mktmpdir do |dir|
      root = File.join(dir, "exercism", "ruby")
      exercise_dir = create_exercise(root, "two-fer")
      state_path = File.join(dir, "state.toml")
      File.write(state_path, %(track = "ruby"\nexercise = "two-fer"\n))
      state = Exercism::Rb::State.new(path: state_path)
      resolver = Exercism::Rb::Resolver.new(state: state, track: "ruby", root: root)

      exercise = resolver.resolve

      assert_equal "two-fer", exercise.slug
      assert_equal exercise_dir, exercise.path
    end
  end

  def test_resolver_reports_missing_current_exercise
    Dir.mktmpdir do |dir|
      resolver = Exercism::Rb::Resolver.new(state: Exercism::Rb::State.new(path: File.join(dir, "state.toml")), root: dir)

      error = assert_raises(Exercism::Rb::Error) { resolver.resolve }

      assert_includes error.message, "No current exercise"
    end
  end
end
