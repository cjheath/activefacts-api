require 'simplecov'
require 'activefacts/api'


SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/activefacts/tracer.rb"
end
