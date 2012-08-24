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
    #
    # Each Constellation maintains an InstanceIndex for each ObjectType in its Vocabulary.
    # The InstanceIndex object is returned when you call @constellation.ObjectType with no
    # arguments (where ObjectType is the object_type name you're interested in)
    #
    class InstanceIndex
      extend Forwardable
      def_delegators :@hash, :size, :empty?, :each, :map,
                     :detect, :values, :detect, :delete_if

      def initialize(constellation, klass)
        @constellation = constellation
        @klass = klass
        @hash = RBTree.new
      end

      def inspect
        "<InstanceIndex for #{@klass.name} in #{@constellation.inspect}>"
      end

      # Assertion of an entity type or a value type
      #
      # When asserting an entity type, multiple entity type or value type
      # may be created. Every instance (entity or value) created in this
      # process will be removed if the entity type fail to be asserted.
      def assert(*args)
        instance, key = *@klass.assert_instance(@constellation, args)
        @klass.created_instances = nil if instance.class.is_entity_type
        instance
      end

      def include?(*args)
        if args.size == 1 && args[0].is_a?(@klass)
          key = args[0].identifying_role_values
        else
          key = @klass.identifying_role_values(*args) rescue nil
        end

        self.[](key)
      end

      def detect &b
        r = @hash.detect &b
        r ? r[1] : nil
      end

      def []=(key, value)   #:nodoc:
        @hash[ComparableHashKey.new(key)] = value
      end

      def [](key)
        @hash[ComparableHashKey.new(key)]
      end

      def keys
        @hash.keys.map { |key| key.value }
      end

      def delete(key)
        @hash.delete(ComparableHashKey.new(key))
      end

      def refresh_key(key)
        value = self.delete(key)
        self.[]=(value, value) if value
      end
    end
  end
end
