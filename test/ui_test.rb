# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbUiTest < ExercismRbTestCase
  def test_color_is_disabled_for_non_tty_by_default
    out = StringIO.new

    with_color_env do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    refute_includes out.string, "\e["
    assert_equal "Saved\n", out.string
  end

  def test_xrb_color_always_forces_color
    out = StringIO.new

    with_color_env("XRB_COLOR" => "always") do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    assert_includes out.string, "\e[32m"
    assert_includes out.string, "Saved"
  end

  def test_warning_and_error_keep_color_on_stderr
    err = StringIO.new

    with_color_env("XRB_COLOR" => "always") do
      ui = Exercism::Rb::UI.new(err: err)
      ui.warn("Careful")
      ui.error("Failed")
    end

    assert_includes err.string, "\e[33mCareful\e[0m"
    assert_includes err.string, "\e[31mFailed\e[0m"
  end

  def test_xrb_color_never_disables_color_even_when_forced
    out = StringIO.new

    with_color_env("XRB_COLOR" => "never", "CLICOLOR_FORCE" => "1") do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    refute_includes out.string, "\e["
  end

  def test_no_color_disables_auto_color
    out = StringIO.new

    with_color_env("NO_COLOR" => "1", "CLICOLOR_FORCE" => "1") do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    refute_includes out.string, "\e["
  end

  def test_auto_color_uses_tty_output
    out = tty_string_io

    with_color_env do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    assert_includes out.string, "\e[32mSaved\e[0m"
  end

  def test_clicolor_zero_disables_tty_auto_color
    out = tty_string_io

    with_color_env("CLICOLOR" => "0") do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    assert_equal "Saved\n", out.string
  end

  def test_clicolor_force_zero_does_not_force_non_tty_color
    out = StringIO.new

    with_color_env("CLICOLOR_FORCE" => "0") do
      Exercism::Rb::UI.new(out: out).success("Saved")
    end

    refute_includes out.string, "\e["
  end

  def test_xrb_color_true_and_false_aliases
    forced = StringIO.new
    disabled = tty_string_io

    with_color_env("XRB_COLOR" => "true") do
      Exercism::Rb::UI.new(out: forced).success("Saved")
    end
    with_color_env("XRB_COLOR" => "false") do
      Exercism::Rb::UI.new(out: disabled).success("Saved")
    end

    assert_includes forced.string, "\e[32mSaved\e[0m"
    assert_equal "Saved\n", disabled.string
  end

  def test_formatter_methods_write_expected_plain_output
    out = StringIO.new
    ui = Exercism::Rb::UI.new(out: out, color: false)

    ui.title("Title")
    ui.section("Section")
    ui.key_value("Path", "/tmp", width: 4)
    ui.command("$ xrb test")

    assert_equal "Title\nSection\nPath /tmp\n$ xrb test\n", out.string
    assert_equal "/tmp", ui.path("/tmp")
    assert_equal "value", ui.highlight("value")
    assert_equal "muted", ui.muted("muted")
  end

  private

  def tty_string_io
    StringIO.new.tap do |out|
      out.define_singleton_method(:tty?) { true }
    end
  end

  def with_color_env(values = {})
    with_env({
      "XRB_COLOR" => nil,
      "NO_COLOR" => nil,
      "CLICOLOR" => nil,
      "CLICOLOR_FORCE" => nil
    }.merge(values)) do
      yield
    end
  end
end
