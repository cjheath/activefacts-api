#
#       ActiveFacts Runtime API
#       InstanceIndex class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'forwardable'

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
                     :detect, :values, :keys, :detect, :delete

      def initialize(constellation, klass)
        @constellation = constellation
        @klass = klass
        @hash = {}
      end

      def inspect
        "<InstanceIndex for #{@klass.name} in #{@constellation.inspect}>"
      end

      def detect &b
        r = @hash.detect &b
        r ? r[1] : nil
      end

      def []=(key, value)   #:nodoc:
        @hash[key] = value
      end

      def [](key)
        @hash[key]
      end

      def refresh_key(key)
        value = @hash.delete(key)
        @hash[value.identifying_role_values(@klass)] = value if value
      end
    end
  end
end
