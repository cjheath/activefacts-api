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
      include FlatHash
      extend Forwardable

      def_delegators :@hash, :size, :empty?, :values

      def initialize
        @hash = RBTree.new
      end

      def +(object)
        if object.is_a?(RoleValues)
          values + object.values
        else
          values + object
        end
      end

      def -(object)
        clone = Hash.new(values)
        if self[object]
          clone.delete(ComparableHashKey.new(object))
        end
        clone.values
      end

      def single
        size > 1 ? nil : @hash.first[1]
      end

      def update(old, value)
        delete(old) if old
        self[value] = value if value
      end

      def to_a
        values
      end

      def include?(key)
        @hash.has_key?(ComparableHashKey.new(key))
      end

      def delete(value)
        if @hash.has_value?(value)
           @hash.delete(@hash.index(value))
        end
      end

      def verbalise
        "[#{@hash.values.map(&:verbalise).join(", ")}]"
      end
    end
  end
end
