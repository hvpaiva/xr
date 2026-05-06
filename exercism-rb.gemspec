# frozen_string_literal: true

require_relative "lib/exercism/rb/version"

Gem::Specification.new do |spec|
  spec.name = "exercism-rb"
  spec.version = Exercism::Rb::VERSION
  spec.authors = ["hvpaiva"]
  spec.summary = "Small Exercism Ruby helper CLI"
  spec.homepage = "https://github.com/hvpaiva/exercism-rb"
  spec.metadata = {
    "source_code_uri" => "https://github.com/hvpaiva/exercism-rb"
  }

  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "README.md", "install.rb"]
  spec.bindir = "bin"
  spec.executables = ["xrb"]
end
