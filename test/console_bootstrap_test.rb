# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbConsoleBootstrapTest < ExercismRbTestCase
  def test_console_bootstrap_loads_solution_and_defines_reload_helper
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "two_fer.rb"), "$xrb_count ||= 0\n$xrb_count += 1\n")

      out, err, status = Dir.chdir(dir) do
        Open3.capture3(
          {"XRB_CONSOLE_SOLUTION_FILE" => "two_fer.rb"},
          RUBY,
          "-I",
          File.join(PROJECT_ROOT, "lib"),
          "-r",
          "exercism/rb/console_bootstrap",
          "-e",
          reload_assertion
        )
      end

      assert status.success?, err
      assert_empty err
      assert_includes out, "Loaded two_fer.rb."
      assert_includes out, "Run reload! after editing two_fer.rb to reload it."
    end
  end

  def test_console_bootstrap_keeps_session_available_when_solution_has_syntax_error
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "two_fer.rb"), "class")

      _out, err, status = Dir.chdir(dir) do
        Open3.capture3(
          {"XRB_CONSOLE_SOLUTION_FILE" => "two_fer.rb"},
          RUBY,
          "-I",
          File.join(PROJECT_ROOT, "lib"),
          "-r",
          "exercism/rb/console_bootstrap",
          "-e",
          "exit(Exercism::Rb::ConsoleBootstrap.reload_solution ? 1 : 0)"
        )
      end

      assert status.success?, err
      assert_includes err, "Could not load two_fer.rb. Fix it and run reload!."
      assert_includes err, "SyntaxError"
    end
  end

  private

  def reload_assertion
    <<~RUBY
      raise "initial load failed" unless $xrb_count == 1

      File.write("two_fer.rb", "$xrb_count += 10\\n")
      raise "reload! returned false" unless reload!
      raise "reload failed" unless $xrb_count == 11
    RUBY
  end
end
