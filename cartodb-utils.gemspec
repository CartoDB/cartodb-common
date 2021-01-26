lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'carto/common/version'

Gem::Specification.new do |spec|
  spec.name = 'cartodb-common'
  spec.version = Carto::Common::VERSION
  spec.authors = ['CARTO']
  spec.summary = 'Gem with common tools for CartoDB, like encryption'
  spec.homepage = 'https://github.com/CartoDB/cartodb-common'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.4'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/}) }
  end

  spec.add_dependency 'argon2', '~> 2'
  spec.add_dependency 'google-cloud-pubsub', '~> 2.3'
  spec.add_dependency 'google-cloud-resource_manager'
  spec.add_dependency 'rails', '>= 4', '< 6'
  spec.add_dependency 'rollbar'

  spec.add_development_dependency 'bundler', '~> 2'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'rubocop', '~> 0.93'
  spec.add_development_dependency 'rubocop-performance'
  spec.add_development_dependency 'rubocop-rails'
  spec.add_development_dependency 'rubocop-rspec'
end
