#
#       ActiveFacts Runtime API
#       InstanceIndex class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'forwardable'
require 'rbtree'

module ActiveFacts
  module API
    class KeyArray < Array
      def initialize(a)
	super(
	  a.map do |e|
	    if e.is_a?(Array) && e.class != self.class
	      KeyArray.new(e)
	    elsif e.eql?(nil)
	      []
	    else
	      e
	    end
	  end
	)
      end

      def inspect
	"KeyArray"+super
      end

      def <=>(other)
	unless other.is_a?(Array)	# Any kind of Array, not just KeyArray
	  return 1
	end

	0.upto size do |i|
	  diff = (s = self[i]) <=> (o = other[i])
	  case diff
	  when 0	# Same value, whether exactly the same class or not
	    next
	  when nil	# Non-comparable values
	    return -1 if s == nil	# Ensure that nil values come before other values
	    return 1 if o == nil
	    return s.class.name <=> o.class.name  # Otherwise just ensure stable sorting
	  else
	    return diff
	  end
	end
	0
      end
    end

    #
    # Each Constellation maintains an InstanceIndex for each ObjectType in its Vocabulary.
    # The InstanceIndex object is returned when you call @constellation.ObjectType with no
    # arguments (where ObjectType is the object_type name you're interested in)
    #
    class InstanceIndex
      extend Forwardable
      def_delegators :@hash, :size, :empty?, :each, :map,
                     :detect, :values, :keys, :detect

      def initialize(constellation, klass, sort)
        @constellation = constellation
        @klass = klass
	@sort = sort
        @hash = sort ? RBTree.new : {}
      end

      def inspect
        "<InstanceIndex for #{@klass.name} in #{@constellation.inspect}>"
      end

      def delete(k)
	@hash.delete(@sort ? form_key(k) : k)
      end

      def detect &b
        r = @hash.detect &b
        r ? r[1] : nil
      end

      def []=(key, value)   #:nodoc:
        @hash[@sort ? form_key(key) : key] = value
      end

      def [](key)
	@hash[@sort ? form_key(key) : key]
      end

      def refresh_key(old_key)
        value = @hash.delete(@sort ? form_key(old_key) : old_key)
        new_key = value.identifying_role_values(@klass)
        @hash[@sort ? form_key(new_key) : new_key] = value if value
      end

      def form_key key
	case key
	when Array
	  KeyArray.new(key)
	when nil
	  []
	else
	  key
	end
      end
    end
  end
end
