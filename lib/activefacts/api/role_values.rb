#
#       ActiveFacts Runtime API
#       RoleValues, manages the set of instances involved in a many_to_one relationship.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API

    class RoleValues  #:nodoc:
      # Paranoia. Because of changes in the implementation, I need to catch old code that calls these delegates incorrectly
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

      def_single_delegator :@a, :all?, 1
      def_single_delegator :@a, :empty?
      def_single_delegator :@a, :include?
      def_single_delegator :@a, :inject, 2
      def_single_delegator :@a, :select, 1
      def_single_delegator :@a, :reject, 1
      def_single_delegator :@a, :size
      def_single_delegator :@a, :sort_by, 1
      def_single_delegator :@a, :to_a
      def_single_delegator :@a, :-
      # These delegators allow a negative arity in RSpec because the tests test it (to make sure the code doesn't pass too many args)
      def_single_delegator :@a, :each, *([1] + Array(defined?(::RSpec) ? -2 : nil))
      def_single_delegator :@a, :detect, 1, *([1] + Array(defined?(::RSpec) ? -2 : nil))
      def_single_delegator :@a, :map, 1, -1

      def initialize
        @a = []
      end

      def +(a)
        @a.+(a.is_a?(RoleValues) ? [a] : a)
      end

      def single
        size > 1 ? nil : @a[0]
      end

      def add_instance(value)
        @a << value
      end

      def delete_instance(value)
        @a.delete value
      end

      def update(old, value)
      end

      def verbalise
        "[#{@a.map(&:verbalise).join(", ")}]"
      end
    end

  end
end
