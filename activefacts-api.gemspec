# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activefacts/api/version'

Gem::Specification.new do |spec|
  spec.name = "activefacts-api"
  spec.version       = ActiveFacts::API::VERSION
  spec.authors       = ["Clifford Heath"]
  spec.email         = ["clifford.heath@gmail.com"]
  spec.date = "2015-10-02"

  spec.summary = "A fact-based data model DSL and API"
  spec.description   = %q{
The ActiveFacts API is a Ruby DSL for managing constellations of elementary facts.
Each fact is either existential (a value or an entity), characteristic (boolean) or
binary relational (A rel B). Relational facts are consistently co-referenced, so you
can traverse them efficiently in any direction. Each constellation maintains constraints
over the fact population.
}
  spec.homepage      = "https://github.com/cjheath/activefacts-api"
  spec.license       = "MIT"

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc",
    "TODO"
  ]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

  spec.add_runtime_dependency(%q<rbtree-pure>, [">= 0.1.1", "~> 0"])

  spec.add_development_dependency "bundler", "~> 1.10.a"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.add_runtime_dependency(%q<ruby-debug>, ["~> 0"]) if RUBY_VERSION < "1.9"
  spec.add_runtime_dependency(%q<debugger>, ["~> 1"]) if RUBY_VERSION =~ /^1\.9/ or RUBY_VERSION =~ /^2\.0/
  spec.add_runtime_dependency(%q<byebug>, ["~> 1"]) if RUBY_VERSION =~ /^2\.1/
  # spec.add_development_dependency(%q<pry>, ["~> 0"]) # rbx, jruby
end

