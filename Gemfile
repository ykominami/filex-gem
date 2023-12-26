# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in filex.gemspec
gemspec

gem 'bundler'
gem 'erubis'
gem 'messagex'
gem 'rake', '~> 13.0'

group :test, optional: true do
  gem 'rspec', '~> 3.0'
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
end

group :development do
  gem 'yard'
end

gem 'activesupport', '~> 7.0.7.1'
