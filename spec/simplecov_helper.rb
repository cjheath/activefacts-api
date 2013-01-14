require 'simplecov'

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/activefacts/tracer.rb"
end

# N.B. This must be loaded after SimpleCov.start
require 'activefacts/api'
