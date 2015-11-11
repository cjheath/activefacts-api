require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rdoc/task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc "Bump gem version patch number"
task :bump do
  path = File.expand_path('../lib/activefacts/api/version.rb', __FILE__)
  lines = File.open(path) do |fp| fp.readlines; end
  File.open(path, "w") do |fp|
    fp.write(
      lines.map do |line|
	line.gsub(/(VERSION *= *"[0-9.]*\.)([0-9]+)"\n/) do
	  version = "#{$1}#{$2.to_i+1}"
	  puts "Version bumped to #{version}\""
	  version+"\"\n"
	end
      end*''
    )
  end
end

desc "Run Rspec tests"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w{-f d}
end

namespace :spec do
  namespace :rubies do
    SUPPORTED_RUBIES = %w{ 1.9.2 1.9.3 2.0.0 jruby-1.7.0 }

    desc "Run Rspec tests on all supported rubies"
    task :all_tasks => [:install_gems, :exec]

    desc "Run `bundle install` on all rubies"
    task :install_gems do
      sh %{ rvm #{SUPPORTED_RUBIES.join(',')} exec bundle install }
    end

    desc "Run `bundle exec rake` on all rubies"
    task :exec do
      sh %{ rvm #{SUPPORTED_RUBIES.join(',')} exec bundle exec rake spec }
    end

    SUPPORTED_RUBIES.each do |ruby|
      desc "Run `bundle install` on #{ruby}"
      task :"install_gems_#{ruby}" do
	sh %{ rvm #{ruby} exec bundle install }
      end

      desc "Run `bundle exec rake` on #{ruby}"
      task :"exec_#{ruby}" do
	sh %{ rvm #{ruby} exec bundle exec rake spec }
      end
    end

  end
end

desc "Run RSpec tests and produce coverage files (results viewable in coverage/index.html)"
RSpec::Core::RakeTask.new(:coverage) do |spec|
  if RUBY_VERSION < '1.9'
    spec.rcov_opts = %{ --exclude spec --exclude lib/activefacts/tracer.rb --exclude gem/* }
    spec.rcov = true
  else
    spec.rspec_opts = %w{ --require simplecov_helper }
  end
end

task :cov => :coverage
task :rcov => :coverage
task :simplecov => :coverage

Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "activefacts-api #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :wait do
  print "Waiting for you to hit Enter"
  $stdin.gets
end
