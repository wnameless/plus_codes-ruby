# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "plus_codes/version"
require "date"

Gem::Specification.new do |s|
  s.name          = "plus_codes"
  s.version       = PlusCodes::VERSION
  s.authors       = ["Wei-Ming Wu"]
  s.date          = Date.today.to_s
  s.email         = ["wnameless@gmail.com"]
  s.summary       = %q{Ruby implementation of Google Open Location Code(Plus+Codes)}
  s.description   = s.summary
  s.homepage      = "https://github.com/wnameless/plus_codes-ruby"
  s.license       = "Apache License, Version 2.0"

  s.files         = %w(LICENSE README.md Rakefile) + Dir.glob("{bin,lib}/**/*")
  # spec.executables = ['your_executable_here']
  s.test_files = Dir["test/**/*"]
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.7"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "test-unit"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "yard"
end
