#
#       ActiveFacts Runtime API
#       RoleValues, manages the set of instances involved in a many_to_one relationship.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'forwardable'

module ActiveFacts
  module API

    class RoleValues  #:nodoc:
      include Enumerable
      extend Forwardable

      def_delegators :@a, :each, :size, :empty?, :values

      def initialize
        @a = RBTree.new
      end

      def +(role_values)
        if role_values.is_a?(RoleValues)
          values + role_values.values
        else
          values + role_values
        end
      end

      def -(a)
        clone = Hash[values]
        if self[a]
          clone.delete(ComparableHashKey.new(a))
        end
        clone.values
      end

      def single
        size > 1 ? nil : @a.first[1]
      end

      def update(old, value)
        delete(old) if old
        self[value] = value if value
      end

      def []=(key, value)   #:nodoc:
        @a[ComparableHashKey.new(key)] = value
      end

      def [](key)
        @a[ComparableHashKey.new(key)]
      end

      def to_a
        values
      end

      def include?(key)
        @a.has_key?(ComparableHashKey.new(key))
      end

      def keys
        @a.keys.map { |key| key.value }
      end

      def delete(value)
        if @a.has_value?(value)
           @a.delete(@a.index(value))
        end
      end

      def verbalise
        "[#{@a.values.map(&:verbalise).join(", ")}]"
      end
    end
  end
end
