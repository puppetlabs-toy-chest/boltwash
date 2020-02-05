# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "boltwash"
  spec.version       = "0.2.0"
  spec.authors       = ["Puppet"]
  spec.email         = ["puppet@puppet.com"]

  spec.summary       = "A Wash plugin for Bolt inventory"
  spec.description   = "A Wash plugin for examining Bolt inventory"
  spec.homepage      = "https://github.com/puppetlabs/boltwash"
  spec.license       = "Apache-2.0"
  spec.files         = Dir["*.rb"]

  spec.required_ruby_version = "~> 2.3"

  spec.add_dependency "bolt", "~> 1.47"
  spec.add_dependency "wash", "~> 0.4"
end
