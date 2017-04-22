# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xcbackyard/version'

Gem::Specification.new do |spec|
  spec.name          = "xcbackyard"
  spec.version       = XCBackyard::VERSION
  spec.authors       = ["Grigoriy Berngardt"]
  spec.email         = ["gregoryvit@gmail.com"]

  spec.summary       = "Utils for Xcode playground injection"
  spec.description   = "This util inject xcode playground to project"
  spec.homepage      = "https://github.com/gregoryvit/XCBackyard"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "xcodeproj"
end
