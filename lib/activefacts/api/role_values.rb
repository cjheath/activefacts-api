#
#       ActiveFacts Runtime API
#       RoleValues, manages the set of instances involved in a many_to_one relationship.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API

    class RoleValues  #:nodoc:
      attr_accessor :role
      attr_accessor :sort
      attr_accessor :index_roles
      def object_type
        @role.object_type
      end

      def initialize role, excluded_role = nil
        @role = role
        # Can't control sorting from the constructor API: @sort = sort == nil ? API::sorted : !!sort
        @sort = API::sorted
        @excluded_role = excluded_role
        @a = @sort ? RBTree.new : []
        (@index_roles = role.object_type.identifying_roles.dup).delete_at(@excluded_role) if @excluded_role
      end

      def +(a)
        if @sort
          @a.values.+(a.is_a?(RoleValues) ? [a] : a)
        else
          @a.+(a.is_a?(RoleValues) ? [a] : a)
        end
      end

      def [](*a)
        if @sort
          #puts "Indexing #{object_type.name}.#{role.name} using #{a.inspect}:\n\t" + caller*"\n\t" + "\n\t---\n"
          key = form_key(a.map{|a| a.respond_to?(:identifying_role_values) ? a.identifying_role_values : a})
          # REVISIT: Consider whether to return an array when a partial key is provided.
          @a[key]
        else
          # Slow: Search the array for an element having the matching key:
          @a.detect{|e| index_values(e) == a}
        end
      end

      def to_a
        @sort ? @a.values : @a
      end

      def to_ary
        to_a
      end

      def keys
        @sort ? @a.keys : @a
      end

      def single
        size > 1 ? nil : to_a[0]
      end

      def form_key a
        a = Array(a)
        if @index_roles && @index_roles.size != a.size
          raise "Incorrectly-sized key #{a.inspect}. Index roles are #{@index_roles.map(&:name).inspect}"
        end
        KeyArray.new(a)
      end

      def index_values object
        if @index_roles
          @index_roles.map{|r|
            role_value = object.send(r.name)
            role_value.identifying_role_values((c = r.counterpart) ? c.object_type : role_value.class)
          }
        else
          object.identifying_role_values
        end
      end

      def add_instance(value, key)
        if @sort
          # Exclude the excluded role, if any:
          (key = key.dup).delete_at(@excluded_role) if @excluded_role
          @a[form_key(key)] = value
        else
          @a << value
        end
      end

      def delete_instance(value, key)
        if @sort
          # Exclude the excluded role, if any:
          (key = key.dup).delete_at(@excluded_role) if @excluded_role
          deleted = @a.delete(form_key(key))
        else
          deleted = @a.delete(value)  # Slow: it has to search the array
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

      # Arity of -1 is needed when a block is passed using to_proc, e.g. map(&:some_method).
      def_single_delegator :@a, :all?, -1, 1
      def_single_delegator :@a, :empty?
      def_single_delegator :@a, :include?
      def_single_delegator :@a, :inject, 2
      def_single_delegator :@a, :select, -1, 1
      def_single_delegator :@a, :reject, -1, 1
      def_single_delegator :@a, :size
      def_single_delegator :@a, :sort_by, -1, 1
      def_single_delegator :@a, :to_a
      def_single_delegator :@a, :-
      # These delegators allow a negative arity in RSpec because the tests test it (to make sure the code doesn't pass too many args)
      def_single_delegator :@a, :each, *([-1, 1] + Array(defined?(::RSpec) ? -2 : nil))
      def_single_delegator :@a, :detect, 1, *([-1, 1] + Array(defined?(::RSpec) ? -2 : nil))
      def_single_delegator :@a, :map, -1, 1
    end
  end
end
