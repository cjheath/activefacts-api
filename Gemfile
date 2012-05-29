source 'https://rubygems.org'

group :development do
  gem 'jeweler'
  gem 'rake'
  gem 'rspec', '~>2.6.0'
end

group :test do
  if RUBY_VERSION < '1.9'
    gem 'rcov', :require => false
  else
    gem 'simplecov', :require => false
  end
end