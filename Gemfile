source 'https://rubygems.org'

gemspec

group :test do
  # rcov 1.0.0 is broken for jruby, so 0.9.11 is the only one available.
  gem 'rcov', '~> 0.9.11', :platforms => [:jruby, :mri_18], :require => false
  gem 'simplecov', '~> 0.6', '>= 0.6.4', :platforms => :mri_19, :require => false
end
