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
                     :detect, :values, :keys, :detect, :delete_if

      def initialize(constellation, klass)
        @constellation = constellation
        @klass = klass
        @hash = {}
      end

      def inspect
        "<InstanceIndex for #{@klass.name} in #{@constellation.inspect}>"
      end

      def include?(*args)
        if args.size == 1 && args[0].is_a?(@klass)
          key = args[0].identifying_role_values
        else
          begin
            key = @klass.identifying_role_values(@constellation, args)
          rescue TypeError => e
            # This happens (and should not) during assert_instance when checking
            # for new asserts of identifying values that might get rolled back
            # when the assert fails (for example because of an implied subtyping change)
            key = nil
          rescue ActiveFactsRuntimeException => e
            # This is currently only known to happen during a retract()
            key = nil
          end
        end

        @hash[key]
      end

      def detect &b
        r = @hash.detect &b
        r ? r[1] : nil
      end

      def []=(key, value)   #:nodoc:
        @hash[flatten_key(key)] = value
      end

      def [](key)
        @hash[flatten_key(key)]
      end

      def refresh_key(key)
        value = @hash.delete(key)
        @hash[value.identifying_role_values] = value if value
      end

      private
      def flatten_key(key)
        if key.is_a?(Array)
          key.map { |identifier| flatten_key(identifier) }
        elsif key.respond_to?(:identifying_role_values)
          key.identifying_role_values
        else
          key
        end
      end
    end
  end
end
