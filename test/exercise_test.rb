# frozen_string_literal: true

require_relative "test_helper"

class XrExerciseTest < XrTestCase
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
end
