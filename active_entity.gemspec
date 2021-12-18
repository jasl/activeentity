# frozen_string_literal: true

require_relative "lib/active_entity/version"

Gem::Specification.new do |spec|
  spec.name        = "activeentity"
  spec.version     = ActiveEntity.gem_version
  spec.authors     = ["jasl"]
  spec.email       = ["jasl9187@hotmail.com"]
  spec.homepage    = "https://github.com/jasl/activeentity"
  spec.summary     = "Rails virtual model solution based on ActiveModel."
  spec.description = "Rails virtual model solution based on ActiveModel designed for Rails 7."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jasl/activeentity"

  spec.required_ruby_version = ">= 2.7.0"

  spec.files        = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.require_path = "lib"

  # spec.extra_rdoc_files = %w(README.rdoc)
  # spec.rdoc_options.concat %w[--main README.rdoc]

  spec.add_dependency "activesupport", "~> 7.0.0", "< 8.0"
  spec.add_dependency "activemodel", "~> 7.0.0", "< 8.0"
end
