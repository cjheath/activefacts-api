require 'rubygems'
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "activefacts-api"
  gem.homepage = "http://github.com/cjheath/activefacts-api"
  gem.license = "MIT"
  gem.summary = "A fact-based data model DSL and API"
  gem.description = %q{
The ActiveFacts API is a Ruby DSL for managing constellations of elementary facts.
Each fact is either existential (a value or an entity), characteristic (boolean) or
binary relational (A rel B). Relational facts are consistently co-referenced, so you
can traverse them efficiently in any direction. Each constellation maintains constraints
over the fact population.
}
  gem.email = "clifford.heath@gmail.com"
  gem.authors = ["Clifford Heath"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  gem.add_development_dependency "rspec", "~> 2.3.0"
  gem.add_development_dependency "bundler", "~> 1.0.0"
  gem.add_development_dependency "jeweler", "~> 1.5.2"
  # gem.add_development_dependency "rcov", ">= 0"
  gem.add_development_dependency "rdoc", ">= 2.4.2"
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rdoc/task'

task :default => :spec

desc "Run Rspec tests"
RSpec::Core::RakeTask.new(:spec)

desc "Run RSpec tests and produce coverage files (results viewable in coverage/index.html)"
RSpec::Core::RakeTask.new(:coverage) do |spec|
  if RUBY_VERSION < '1.9'
    spec.rcov_opts = [
        '--exclude', 'spec',
        '--exclude', 'lib/activefacts/tracer.rb',
        '--exclude', 'gem/*'
      ]
    spec.rcov = true
  else
    spec.rspec_opts = ['--require', 'simplecov_helper']
  end
end

Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "activefacts-api #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
