#
#       ActiveFacts Runtime API
#       Numeric and Date delegates and hacks to handle immediate types.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
# These delegates are required because Integer & Float don't support new,
# and can't be sensibly subclassed. Just delegate to an instance var.
# Date and DateTime don't have a sensible new() method, so we monkey-patch one here.
#
require 'delegate'
require 'date'
require 'bigdecimal'

module ActiveFacts
  module API
    # Fixes behavior of core functions over multiple platform
    module SimpleDelegation
      def initialize(v)
        __setobj__(delegate_new(v))
      end

      def eql?(v)
        # Note: This and #hash do not work the way you'd expect,
        # and differently in each Ruby interpreter. If you store
        # an Int or Real in a hash, you cannot reliably retrieve
        # them with the corresponding Integer or Real.
        __getobj__.eql?(delegate_new(v))
      end

      def ==(o)                             #:nodoc:
        __getobj__.==(o)
      end

      def to_s *a                            #:nodoc:
        __getobj__.to_s *a
      end

      def to_json(*a)                       #:nodoc:
        __getobj__.to_s
      end

      def hash                              #:nodoc:
        __getobj__.hash
      end

      def is_a?(k)
        __getobj__.is_a?(k) || super
      end

      def kind_of?(k)
        is_a?(k)
      end

      def inspect
        "#{self.class.basename}:#{__getobj__.inspect}"
      end
    end
  end
end

class Decimal < SimpleDelegator #:nodoc:
  include ActiveFacts::API::SimpleDelegation

  def delegate_new(v)
    if v.is_a?(BigDecimal) || v.is_a?(Bignum)
      BigDecimal.new(v.to_s)
    else
      BigDecimal.new(v)
    end
  end
end

# It's not possible to subclass Integer, so instead we delegate to it.
class Int < SimpleDelegator
  include ActiveFacts::API::SimpleDelegation

  def delegate_new(i = nil)               #:nodoc:
    Integer(i)
  end
end

# It's not possible to subclass Float, so instead we delegate to it.
class Real < SimpleDelegator
  include ActiveFacts::API::SimpleDelegation

  def delegate_new(r = nil)               #:nodoc:
    Float(r)
  end
end

# A Date can be constructed from any Date subclass, not just using the normal date constructors.
class ::Date
  class << self; alias_method :old_new, :new end
  # Date.new cannot normally be called passing a Date as the parameter. This allows that.
  def self.new(*a, &b)
    if (a.size == 1 && a[0].is_a?(Date))
      a = a[0]
      civil(a.year, a.month, a.day, a.start)
    elsif (a.size == 1 && a[0].is_a?(String))
      parse(a[0])
    else
      civil(*a, &b)
    end
  end
end

# A DateTime can be constructed from any Date or DateTime subclass
class ::DateTime
  class << self; alias_method :old_new, :new end
  # DateTime.new cannot normally be called passing a Date or DateTime as the parameter. This allows that.
  def self.new(*a, &b)
    if (a.size == 1)
      a = a[0]
      if (DateTime === a)
        civil(a.year, a.month, a.day, a.hour, a.min, a.sec, a.start)
      elsif (Date === a)
        civil(a.year, a.month, a.day, 0, 0, 0, a.start)
      else
        civil(*a, &b)
      end
    else
      civil(*a, &b)
    end
  end
end

# The AutoCounter class is an integer, but only after the value
# has been established in the database.
# Construct it with the value :new to get an uncommitted value.
# You can use this new instance as a value of any role of this type, including to identify an entity instance.
# The assigned value will be filled out everywhere it needs to be, upon save.
class AutoCounter
  def initialize(i = :new)
    raise "AutoCounter #{self.class} may not be #{i.inspect}" unless i == :new or i.is_a?(Integer) or i.is_a?(AutoCounter)
    @@placeholder ||= 0
    if i == :new
      @value = nil
      @initially = (@@placeholder+=1)
    else
      @initially = @value = i.to_i;
    end
  end

  # Assign a definite value to an AutoCounter; this may only be done once
  def assign(i)
    raise ArgumentError, "Illegal attempt to assign integer value of a committed AutoCounter" if @value
    @value = i.to_i
  end

  # Ask whether a definite value has been assigned
  def defined?
    !@value.nil?
  end

  def to_s
    if self.defined?
      @value.to_s 
    else
      "new_#{@initially}"
    end
  end

  # An AutoCounter may only be used in numeric expressions after a definite value has been assigned
  def to_i
    raise ArgumentError, "Illegal attempt to get integer value of an uncommitted AutoCounter" unless @value
    @value
  end

  # Coerce "i" to be of the same type as self
  def coerce(i)
    raise ArgumentError, "Illegal attempt to use the value of an uncommitted AutoCounter" unless @value
    [ i.to_i, @value ]
  end

  def inspect
    "\#<AutoCounter "+to_s+">"
  end

  def <=>(other)
    to_s <=> other.to_s
  end

  def ==(other)
    to_s == other.to_s
  end

  def eql?(o)                           #:nodoc:
    to_s.eql?(o.to_s)
  end

  def self.inherited(other)             #:nodoc:
    def other.identifying_role_values(*args)
      return nil if args == [:new]  # A new object has no identifying_role_values
      if args.size == 1
        return args[0] if args[0].is_a?(AutoCounter)
        return args[0].send(self.basename.snakecase.to_sym) if args[0].respond_to?(self.basename.snakecase.to_sym)
      end
      return new(*args)
    end
    super
  end

  def clone
    raise "Not allowed to clone AutoCounters"
  end
end
