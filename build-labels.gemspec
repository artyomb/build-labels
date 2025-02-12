#lib = File.expand_path('lib', __dir__)
#$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'build-labels'
  s.version     = BuildLabels::Builder::VERSION
  s.executables << 'build-labels'
  s.executables << 'helm-push'
  s.summary     = 'Generate docker build image labels from CI variables'
  s.description = ''
  s.authors     = ['Artyom B']
  s.email       = 'author@email.address'
  s.files       = Dir['{bin,lib,test,examples}/**/*']

  s.bindir        = 'bin'
  s.require_paths = ['lib']
  s.homepage    = 'https://rubygems.org/gems/build-labels'
  s.license     = 'Nonstandard' # http://spdx.org/licenses
  s.metadata    = { 'source_code_uri' => 'https://github.com/artyomb/build-labels' }

  s.required_ruby_version = ">= " + File.read(File.dirname(__FILE__)+'/.ruby-version').strip

  # s.add_runtime_dependency ''

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.10"
  s.add_development_dependency "rubocop", "~> 1.63.2"
  s.add_development_dependency "rubocop-rake", "~> 0.6.0"
  s.add_development_dependency "rubocop-rspec", "~> 2.14.2"
  s.add_development_dependency "rspec_junit_formatter", "~> 0.5.1"
end
