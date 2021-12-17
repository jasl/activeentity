# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)

require "active_entity/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activeentity"
  s.version     = ActiveEntity::VERSION::STRING
  s.authors     = ["jasl"]
  s.email       = ["jasl9187@hotmail.com"]
  s.homepage    = "https://github.com/jasl/activeentity"
  s.summary     = "Rails virtual model solution based on ActiveModel."
  s.description = "Rails virtual model solution based on ActiveModel design for Rails 6+."
  s.license     = "MIT"

  s.required_ruby_version = ">= 2.5.0"

  s.files        = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.require_path = "lib"

  # s.extra_rdoc_files = %w(README.rdoc)
  # s.rdoc_options.concat %w[--main README.rdoc]

  s.add_dependency "activesupport", ">= 6.0", "< 8.0"
  s.add_dependency "activemodel", ">= 6.0", "< 8.0"
end
