# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eventboss/version'

Gem::Specification.new do |spec|
  spec.name          = "eventboss"
  spec.version       = Eventboss::VERSION
  spec.authors       = ["AirHelp"]
  spec.email         = ["marcin.naglik@airhelp.com"]

  spec.summary       = %q{Eventboss Ruby Client.}
  spec.description   = %q{Eventboss Ruby Client.}
  spec.homepage      = "https://github.com/AirHelp/eventboss"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = ["eventboss"]
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", "~> 1.0", ">= 1.0.5"
  spec.add_dependency "aws-sdk-sqs", ">= 1.3.0"
  spec.add_dependency "aws-sdk-sns", ">= 1.1.0"
  spec.add_dependency "dotenv", "~> 2.1", ">= 2.1.1"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency 'rake', '>= 10.0'
  spec.add_development_dependency "rspec", "~> 3.0"
end
