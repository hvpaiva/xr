# frozen_string_literal: true

require_relative "lib/xr/version"

Gem::Specification.new do |spec|
  spec.name = "xr"
  spec.version = Xr::VERSION
  spec.authors = ["hvpaiva"]
  spec.summary = "Small Exercism Ruby helper CLI"

  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "README.md", "install.rb"]
  spec.bindir = "bin"
  spec.executables = ["xr"]
end
