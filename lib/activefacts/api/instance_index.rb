#
#       ActiveFacts Runtime API
#       InstanceIndex class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
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

      # This is used by RBTree for searching, and we need it to use eql? semantics to be like a Hash
      def ==(other)
        self.eql? other
      end

      def <=>(other)
        unless other.is_a?(Array)       # Any kind of Array, not just KeyArray
          return 1
        end

        0.upto(size-1) do |i|
          diff = ((s = self[i]) <=> (o = other[i]) rescue nil)
          case diff
          when 0        # Same value, whether exactly the same class or not
            next
          when nil      # Non-comparable values
            return -1 if s == nil       # Ensure that nil values come before other values
            return 1 if o == nil
            diff = s.class.name <=> o.class.name  # Otherwise just ensure stable sorting
            return diff if diff != 0
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
      attr_reader :sort
      attr_reader :object_type

      # Should be in module ForwardableWithArityChecking
      def self.def_single_delegator(accessor, method, *expected_arities)
        str = %{
          def #{method}(*args, &block)
            if #{expected_arities.size == 0 ? "block" : "!block || !#{expected_arities.inspect}.include?(block.arity)" }
              raise ArgumentError.new("Arity mismatch on #{name}\##{method}, got \#{block ? block.arity : 'none'} want #{expected_arities.inspect} at \#{caller*"\n\t"})")
            end
            #{accessor}.__send__(:#{method}, *args, &block)
          end
        }
        eval(str)
      end

      def_single_delegator :@hash, :size
      def_single_delegator :@hash, :empty?
      def_single_delegator :@hash, :each, -1, 1, 2, -3
      def_single_delegator :@hash, :map, -1, 1, 2, -3
      def_single_delegator :@hash, :detect, -1, 1
      def_single_delegator :@hash, :values
      def_single_delegator :@hash, :keys

      def initialize(constellation, object_type, sort)
        @constellation = constellation
        @object_type = object_type
        @sort = sort
        @hash = sort ? RBTree.new : {}
      end

      def inspect
        "<InstanceIndex for #{@object_type.name} in #{@constellation.inspect}>"
      end

      def add_instance(instance, k)
        self[k] = instance
      end

      def delete_instance(instance, k)
        @hash.delete(@sort ? form_key(k) : k)
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
        new_key = value.identifying_role_values(@object_type)
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
