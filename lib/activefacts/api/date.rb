#
#       ActiveFacts Runtime API
#       Date hacks to handle immediate types.
#
# Copyright (c) 2013 Clifford Heath. Read the LICENSE file.
#
# Date and DateTime don't have a sensible new() method, so we monkey-patch one here.
#
require 'date'

# A Date can be constructed from any Date or DateTime subclass, or parsed from a String
class ::Date
  if defined?(RUBY_ENGINE) and RUBY_ENGINE == 'ruby'
    def initialize *a, &b
      # If someone calls allocate/initialize, make that work.
      marshal_load(self.class.new(*a, &b).marshal_dump) unless self.is_a?(DateTime)
    end
  end

  def self.new *a, &b
    if a[0].is_a?(String)
      parse(*a)
    elsif (a.size == 1)
      case a[0]
      when DateTime
	civil(a[0].year, a[0].month, a[0].day, a[0].start)
      when Date
	a[0].clone
      else
	civil(*a, &b)
      end
    else
      civil(*a, &b)
    end
  end
end

# A DateTime can be constructed from any Date or DateTime subclass, or parsed from a String
class ::DateTime
  if defined?(RUBY_ENGINE) and RUBY_ENGINE == 'ruby'
    def initialize *a, &b
      # If someone calls allocate/initialize, make that work.
      marshal_load(self.class.new(*a, &b).marshal_dump)
    end
  end

  def self.new *a, &b
    if a[0].is_a?(String)
      parse(*a)
    elsif (a.size == 1)
      case a[0]
      when DateTime
	a[0].clone
      when Date
	civil(a[0].year, a[0].month, a[0].day, 0, 0, 0, a[0].start)
      else
	civil(*a, &b)
      end
    else
      civil(*a, &b)
    end
  end
end
