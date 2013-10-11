#
#       ActiveFacts Runtime API
#       RoleValues, manages the set of instances involved in a many_to_one relationship.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API

    class RoleValues  #:nodoc:
      attr_accessor :sort

      def initialize sort = false
	@sort = !!(sort || ENV[@@af_sort_name ||= "ACTIVEFACTS_SORT"])
        @a = @sort ? RBTree.new : []
      end

      def +(a)
	if @sort
	  @a.values.+(a.is_a?(RoleValues) ? [a] : a)
	else
	  @a.+(a.is_a?(RoleValues) ? [a] : a)
	end
      end

      def to_a
	@sort ? @a.values : @a
      end

      def keys
	@sort ? @a.keys : @a
      end

      def single
        size > 1 ? nil : to_a[0]
      end

      def form_key a
	KeyArray.new(Array(a))
      end

      def add_instance(value, key)
	if @sort
	  @a[form_key(key)] = value
	else
	  @a << value
	end
      end

      def delete_instance(value, key)
	if @sort
	  deleted = @a.delete(form_key(key))
	else
	  deleted = @a.delete(value)
	end

	# Test code:
	unless deleted
	  p @a
	  p value
	  debugger
	  true
	end

      end

      def verbalise
	a = @sort ? @a.values : @a
        "[#{a.map(&:verbalise).join(", ")}]"
      end

      # Paranoia. Because of changes in the implementation, I need to catch old code that calls these delegates incorrectly
      def self.def_single_delegator(accessor, method, *expected_arities)
	str = %{
	  def #{method}(*args, &block)
	    if #{expected_arities.size == 0 ? "block" : "!block || !#{expected_arities.inspect}.include?(block.arity)" }
	      raise ArgumentError.new("Arity mismatch on #{name}\##{method}, got \#{block ? block.arity : 'none'} want #{expected_arities.inspect} at \#{caller*"\n\t"})")
	    end
	    if @sort
	      #{accessor}.values.__send__(:#{method}, *args, &block)
	    else
	      #{accessor}.__send__(:#{method}, *args, &block)
	    end
	  end
	}
	eval(str)
      end

      def include? v
	if @sort
	  @a.include?(form_key(v))
	else
	  @a.include?(v)
	end
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
    end
  end
end
