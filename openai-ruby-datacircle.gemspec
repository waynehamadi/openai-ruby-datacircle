# frozen_string_literal: true

require_relative 'lib/openai_ruby_datacircle/version'

Gem::Specification.new do |spec|
  spec.name          = 'openai-ruby-datacircle'
  spec.version       = OpenAI::Datacircle::VERSION
  spec.authors       = ['Wayne Hamadi']
  spec.email         = ['wayne@datacircle.dev']

  spec.summary       = 'Find the best GTM APIs from the official OpenAI Ruby SDK.'
  spec.description   = 'Four function tools of the openai gem call Datacircle\'s open API with no key. List the GTM ' \
                       'APIs and each API\'s best plans. Search every plan, or see where one provider ranks in our ' \
                       'benchmarks. We benchmark all the GTM APIs and we put the results on our website: ' \
                       'https://datacircle.dev'
  spec.homepage      = 'https://datacircle.dev'
  spec.license       = 'MIT'
  spec.metadata      = {
    'homepage_uri' => 'https://datacircle.dev',
    'source_code_uri' => 'https://github.com/waynehamadi/openai-ruby-datacircle',
    'documentation_uri' => 'https://github.com/waynehamadi/openai-ruby-datacircle#readme',
    'bug_tracker_uri' => 'https://github.com/waynehamadi/openai-ruby-datacircle/issues'
  }

  spec.files         = Dir['LICENSE.txt', 'README.md', 'lib/**/*.rb']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.2.0'

  spec.add_dependency 'openai', '>= 0.9.0', '< 2'
end
