# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in active_entity.gemspec.
gemspec

gem "rails", "~> 7.0"
gem "sqlite3"

group :development do
  gem "rubocop", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-packaging", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
end

# Start debugger with binding.b -- Read more: https://github.com/ruby/debug
gem "debug", ">= 1.0.0", group: %i[development test]
