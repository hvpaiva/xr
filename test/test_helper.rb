# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "stringio"
require "tmpdir"

require_relative "../lib/exercism/rb"

module ExercismRbTestHelpers
  PROJECT_ROOT = File.expand_path("..", __dir__)
  RUBY = RbConfig.ruby

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
      "XRB_ROOT" => root,
      "XRB_STATE" => state_path,
      "XRB_TRACK" => "ruby"
    }.merge(extra_env)

    code = with_env(env) { Exercism::Rb::CLI.start(argv, out: out, err: err) }

    [code, out.string, err.string]
  end

  def run_bin(*args, root:, state_path:, extra_env: {})
    env = {
      "XRB_ROOT" => root,
      "XRB_STATE" => state_path,
      "XRB_TRACK" => "ruby"
    }.merge(extra_env)

    out, err, status = Open3.capture3(env, RUBY, File.join(PROJECT_ROOT, "bin/xrb"), *args)

    [status.exitstatus, out, err]
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
      "XRB_COMMAND_LOG" => log_path
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
      } >> "$XRB_COMMAND_LOG"
      #{body}
      exit "${XRB_FAKE_EXIT:-0}"
    SH
    File.chmod(0o755, path)
  end

  def assert_command_log(log_path, command:, pwd:, args:)
    assert_includes File.read(log_path), command_record(command: command, pwd: pwd, args: args)
  end

  def assert_command_sequence(log_path, *entries)
    expected = entries.map { |entry| command_record(**entry) }.join

    assert_equal expected, File.read(log_path)
  end

  def command_record(command:, pwd:, args:)
    "command=#{command}\npwd=#{pwd}\nargs=#{args.map { |arg| "[#{arg}]" }.join}\n"
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

class ExercismRbTestCase < Minitest::Test
  include ExercismRbTestHelpers
end
