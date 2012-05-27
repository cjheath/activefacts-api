source 'https://rubygems.org'

group :development do
  gem 'jeweler'
  gem 'rspec'
  gem 'rake'
end

group :test do
  if RUBY_VERSION < '1.9'
    gem 'rcov', :require => false
  else
    gem 'simplecov', :require => false
  end
end