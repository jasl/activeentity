# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem"s dependencies in virtual_record.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# Your gem is dependent on dev or edge Rails. Once you can lock this
# dependency down to a specific version, move it to your gemspec.
gem "rails", ">= 6.0.0.rc1"

gem "sqlite3", "~> 1.4"

# Use Puma as the app server
gem "puma", "~> 3.11"
# Use SCSS for stylesheets
# gem "sassc-rails"
# Use Uglifier as compressor for JavaScript assets
# gem "uglifier", ">= 1.3.0"
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem "mini_racer", platforms: :ruby

# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
# gem "turbolinks", "~> 5"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem "jbuilder", "~> 2.5"

# Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
gem "web-console"
# Call "byebug" anywhere in the code to stop execution and get a debugger console
gem "pry-byebug", group: [:development, :test]

# For better console experience
gem "pry-rails"

gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rails"
