# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "active_entity/version"

# Describe your gem and declare its dependencies:
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

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.required_ruby_version = ">= 2.5.0"
  s.add_dependency "activesupport", ">= 6.0.0.beta1", "< 7.0"
  s.add_dependency "activemodel",   ">= 6.0.0.beta1", "< 7.0"
end
