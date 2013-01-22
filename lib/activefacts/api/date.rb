#
#       ActiveFacts Runtime API
#       Date hacks to handle immediate types.
#
# Copyright (c) 2013 Clifford Heath. Read the LICENSE file.
#
# Date and DateTime don't have a sensible new() method, so we monkey-patch one here.
#
require 'date'
require 'time'

# A Date can be constructed from any Date or DateTime subclass, or parsed from a String
class ::Date
  def self.new_instance constellation, *a, &b
    if a[0].is_a?(String)
      d = parse(*a)
    elsif (a.size == 1)
      case a[0]
      when DateTime
	d = civil(a[0].year, a[0].month, a[0].day, a[0].start)
      when Date
	d = civil(a[0].year, a[0].month, a[0].day, a[0].start)
      when NilClass
	d = civil()
      else
	d = civil(*a, &b)
      end
    else
      d = civil(*a, &b)
    end
    d.send(:instance_variable_set, :@constellation, constellation)
    d
  end
end

# A DateTime can be constructed from any Date or DateTime subclass, or parsed from a String
class ::DateTime

  def self.new_instance constellation, *a, &b
    if a[0].is_a?(String)
      dt = parse(*a)
    elsif (a.size == 1)
      case a[0]
      when DateTime
	dt = civil(a[0].year, a[0].month, a[0].day, a[0].hour, a[0].min, a[0].sec, a[0].start)
      when Date
	dt = civil(a[0].year, a[0].month, a[0].day, 0, 0, 0, a[0].start)
      when NilClass
	dt = civil()
      else
	dt = civil(*a, &b)
      end
    else
      dt = civil(*a, &b)
    end
    dt.send(:instance_variable_set, :@constellation, constellation)
    dt
  end

end

class ::Time
  def identifying_role_values klass = nil
    self
  end

  def self.new_instance constellation, *a
    t =
      if a[0].is_a?(Time)
       at(a[0])
      else
       begin
         local(*a)
       end
      end

=begin
    if a[0].is_a?(String)
      parse(*a)
    elsif (a.size == 1)
      case a[0]
      when DateTime
       a[0].clone
      when Date
       civil(a[0].year, a[0].month, a[0].day, 0, 0, 0, a[0].start)
      when NilClass
       civil()
      else
       civil(*a, &b)
      end
    else
      civil(*a, &b)
    end
=end

    t.send(:instance_variable_set, :@constellation, constellation)
    t
  end

end
