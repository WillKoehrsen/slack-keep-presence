# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "slack_keep_presence/version"

Gem::Specification.new do |spec|
  spec.name          = "slack-keep-presence"
  spec.version       = SlackKeepPresence::VERSION
  spec.authors       = ["Josh Frye"]
  spec.email         = ["josh@joshfrye.com"]

  spec.summary       = "Disable Slack auto-away"
  spec.description   = "Mark your Slack user as active when auto-away kicks in"
  spec.homepage      = "https://github.com/joshfng/slack-keep-presence"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "bin"
  spec.executables   = ["slack-keep-presence"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = "~> 2.7.4"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_runtime_dependency "faye-websocket", "~> 0.10"
  spec.add_runtime_dependency "slack-api", "~> 1.6"
end
