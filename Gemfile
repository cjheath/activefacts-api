source 'https://rubygems.org'

gem 'rake', '~> 10.1', :group => [:development, :test]
gem 'rbtree-pure', '~> 0'

group :development do
  gem 'jeweler', '~> 0'
  gem 'rspec', '~> 2.6', '>= 2.6.0'
  gem 'ruby-debug', '~> 0', :platforms => [:mri_18]
  gem 'debugger', '~> 0', :platforms => [:mri_19,
    (['1.8.7', '1.9.2'].include?(RUBY_VERSION) || RUBY_PLATFORM == 'java') ? nil : :mri_20
  ].compact
  gem 'pry', '~> 0', :platforms => [:jruby, :rbx]
end

group :test do
  # rcov 1.0.0 is broken for jruby, so 0.9.11 is the only one available.
  gem 'rcov', '~> 0.9.11', :platforms => [:jruby, :mri_18], :require => false
  gem 'simplecov', '~> 0.6', '>= 0.6.4', :platforms => :mri_19, :require => false
end
