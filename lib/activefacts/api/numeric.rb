#
#       ActiveFacts Runtime API
#       Numeric delegates and hacks to handle immediate types.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
# These delegates are required because Integer & Float don't support new,
# and can't be sensibly subclassed. Just delegate to an instance var.
# Date and DateTime don't have a sensible new() method, so we monkey-patch one here.
#
require 'delegate'
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
    if v.is_a?(BigDecimal) || v.is_a?(Integer)
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

# The AutoCounter class is an integer, but only after the value
# has been established in the database.
# Construct it with the value :new to get an uncommitted value.
# You can use this new instance as a value of any role of this type, including to identify an entity instance.
# The assigned value will be filled out everywhere it needs to be, upon save.
module ActiveFacts
  module AutoCounterClass
    def identifying_role_values(constellation, args)
      arg_hash = args[-1].is_a?(Hash) ? args.pop : {}
      n = 
        case
        when args == [:new]     # A new object has no identifying_role_values
          :new
        when args.size == 1 && args[0].is_a?(AutoCounter)
          args[0]               # An AutoCounter is its own key
        else
          new(*args)
        end
      args.replace([arg_hash])
      n
    end
  end
end

class AutoCounter
  attr_reader :place_holder_number
  def initialize(i = :new)
    unless i == :new or i.is_a?(Integer) or i.is_a?(AutoCounter)
      raise ArgumentError.new("AutoCounter #{self.class} may not be #{i.inspect}")
    end
    @@place_holder ||= 0
    case i
    when :new
      @value = nil
      @place_holder_number = (@@place_holder+=1)
    when AutoCounter
      if i.defined?
        @value = i.to_i
      else
        @place_holder_number = i.place_holder_number
        @value = nil
      end
    else
      @place_holder_number = @value = i.to_i;
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
      "new_#{@place_holder_number}"
    end
  end

  # if the value is unassigned, it equal?(:new).
  def equal? value
    value == :new ? @value == nil : super
  end

  # An AutoCounter may only be used in numeric expressions after a definite value has been assigned
  def to_i
    unless @value
      raise ArgumentError, "Illegal attempt to get integer value of an uncommitted AutoCounter"
    end
    @value
  end

  # Coerce "i" to be of the same type as self
  def coerce(i)
    unless @value
      raise ArgumentError, "Illegal attempt to use the value of an uncommitted AutoCounter"
    end
    [ i.to_i, @value ]
  end

  def inspect
    "\#<AutoCounter "+to_s+">"
  end

  def hash                              #:nodoc:
    if self.defined?
      @value.hash
    else
      @place_holder_number
    end
  end

  def eql?(o)                           #:nodoc:
    to_s.eql?(o.to_s)
  end

  def <=>(o)                            #:nodoc:
    if self.defined? && !o == [] && o.defined?
      if (c = (self.class <=> o.class.name)) != 0
        return c
      else
        return to_i <=> o.to_i
      end
    else
      to_s.<=>(o.to_s)
    end
  end

  def identifying_role_values klass = nil
    self
  end

#  extend ActiveFacts::AutoCounterClass
  def self.inherited(other)             #:nodoc:
    other.class_eval do
      extend ActiveFacts::AutoCounterClass
    end
    super
  end

  def clone
    raise "Not allowed to clone AutoCounters"
  end
end
