$:.push File.expand_path('../lib', __FILE__)
require 'flintlock/version'

Gem::Specification.new do |gem|
  gem.name = 'flintlock'
  gem.version = Flintlock::VERSION
  gem.summary = "A simple application deployer"
  gem.description = "A simple application deployer inspired by Heroku's buildpacks"
  gem.authors = ['Jon McKenzie']
  gem.email = 'jcmcken@gmail.com'
  gem.homepage = 'https://github.com/jcmcken/flintlock'
  gem.license = 'MIT'

  gem.files = Dir['lib/**/*'] + ['LICENSE', 'README.md', 'CHANGES.md']
  gem.executables = ['flintlock']
  gem.require_paths = ['lib']  

  gem.required_ruby_version = '>= 1.9.3'
  gem.add_runtime_dependency 'thor'
  gem.add_runtime_dependency 'json'
  
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'fakefs'
end
