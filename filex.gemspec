# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'filex/version'

Gem::Specification.new do |spec|
  spec.name          = 'filex'
  spec.version       = Filex::VERSION
  spec.authors       = ['yasuo kominami']
  spec.email         = ['ykominami@gmail.com']

  spec.summary       = 'Load a text file, yaml fortmat file and eruby format file and expand it.'
  spec.description   = 'Load a text file, yaml fortmat file and eruby format file and expand it.'
  spec.homepage      = ''
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
  #    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  #    spec.metadata["homepage_uri"] = spec.homepage
  #    spec.metadata["source_code_uri"] = "text file, yaml format file and eruby format file2 file operation"
  #    spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler'
  spec.add_dependency 'erubis'
  spec.add_dependency 'messagex'
  spec.add_dependency 'rake', '~> 13.0'

  #  spec.add_development_dependency 'rspec', '~> 3.0'
  #  spec.add_development_dependency 'rubocop'
  #  spec.add_development_dependency 'rubocop-performance'
  #  spec.add_development_dependency 'rubocop-rails'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
