# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rbconfig"
require "tmpdir"

RUBY = RbConfig.ruby
PROJECT_ROOT = __dir__
VERSION_FILE = File.join(PROJECT_ROOT, "lib/exercism/rb/version")

Rake::TestTask.new(:test) do |task|
  task.libs = %w[lib test]
  task.test_files = FileList["test/exercism_rb_test.rb"]
  task.verbose = true
end

desc "Check Ruby syntax for project files"
task :syntax do
  files = FileList[
    "bin/xrb",
    "lib/**/*.rb",
    "test/**/*.rb",
    "exercism-rb.gemspec",
    "Rakefile"
  ]

  files.each do |file|
    sh RUBY, "-c", file
  end
end

desc "Run the test suite with Ruby warnings enabled"
task :warnings do
  sh RUBY, "-w", "-Ilib:test", "test/exercism_rb_test.rb"
end

desc "Run style checks"
task :style do
  sh "bundle", "exec", "standardrb"
end

desc "Run dependency audit"
task :audit do
  sh "bundle", "exec", "bundle-audit", "check", "--update"
end

desc "Run required quality checks"
task quality: [:style, :audit]

desc "Run Reek smell report"
task :smells do
  sh "bundle", "exec", "reek", "lib"
end

desc "Generate RubyCritic report"
task :critic do
  sh "bundle", "exec", "rubycritic", "--no-browser", "lib", "test"
end

desc "Run tests with coverage enabled"
task :coverage do
  sh({"COVERAGE" => "1"}, RUBY, "-Ilib:test", "test/exercism_rb_test.rb")
end

namespace :smoke do
  desc "Run the checkout executable as a user would invoke it"
  task :bin do
    sh RUBY, File.join(PROJECT_ROOT, "bin/xrb"), "version"
    sh RUBY, File.join(PROJECT_ROOT, "bin/xrb"), "help"
  end

  desc "Build, install, and run the packaged gem in an isolated GEM_HOME"
  task gem: :build do
    gem_path = File.join(PROJECT_ROOT, "pkg", "exercism-rb-#{gem_version}.gem")
    raise "Built gem not found: #{gem_path}" unless File.file?(gem_path)

    Dir.mktmpdir("exercism-rb-gem-home") do |gem_home|
      env = isolated_gem_env(gem_home)

      Bundler.with_unbundled_env do
        sh env, RUBY, "-S", "gem", "install", "--local", gem_path, "--no-document"

        xrb = File.join(gem_home, "bin", "xrb")
        sh env, xrb, "version"
        sh env, xrb, "help"
      end
    end
  end
end

namespace :release do
  desc "Validate that the release tag matches the gem version"
  task :validate_tag do
    tag = ENV.fetch("GITHUB_REF_NAME", ENV.fetch("TAG", nil))
    expected = "v#{gem_version}"

    raise "Release tag is required" if tag.nil? || tag.empty?
    raise "Release tag #{tag.inspect} does not match #{expected.inspect}" unless tag == expected
  end
end

desc "Run the full local verification suite"
task ci: [:syntax, :test, :warnings, :quality, "smoke:bin", "smoke:gem"]

task default: :test

def gem_version
  content = File.read("#{VERSION_FILE}.rb")
  match = content.match(/VERSION = "([^"]+)"/)
  raise "Could not find VERSION in #{VERSION_FILE}.rb" unless match

  match[1]
end

def isolated_gem_env(gem_home)
  {
    "GEM_HOME" => gem_home,
    "GEM_PATH" => gem_home,
    "PATH" => [File.join(gem_home, "bin"), ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
  }
end
