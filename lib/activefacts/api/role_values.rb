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

      def initialize(role, entity)
        @hash = RBTree.new
        @role = role
        @entity = entity
      end

      def +(object)
        if object.is_a?(RoleValues)
          values + object.values
        else
          values + object
        end
      end

      def -(object)
        values - object
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
        @hash.has_key?(serialize_key(key))
      end

      def delete(value)
        if @hash.has_value?(value)
           @hash.delete(@hash.index(value))
        end
      end

      def verbalise
        "[#{@hash.values.map(&:verbalise).join(", ")}]"
      end

      def [](key)
        @hash[serialize_key(rebuild_from_residual(key))]
      end

      def rebuild_from_residual(key)
        if @role.counterpart.is_identifying
          irv_position = @role.counterpart.object_type.identifying_roles.index(@role.counterpart)
          key.insert(irv_position, @entity.identifying_role_values)
        else
          key
        end
      end
    end
  end
end
