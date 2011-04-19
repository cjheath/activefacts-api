#
#       ActiveFacts Runtime API
#       InstanceIndex class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API
    #
    # Each Constellation maintains an InstanceIndex for each ObjectType in its Vocabulary.
    # The InstanceIndex object is returned when you call @constellation.ObjectType with no
    # arguments (where ObjectType is the object_type name you're interested in)
    #
    class InstanceIndex
      def initialize(constellation, klass)
        @constellation = constellation
        @klass = klass
        @hash = {}
      end

      def inspect
        "<InstanceIndex for #{@klass.name} in #{@constellation.inspect}>"
      end

      def assert(*args)
        #trace :assert, "Asserting #{@klass} with #{args.inspect}" do
          instance, key = *@klass.assert_instance(@constellation, args)
          instance
        #end
      end

      def include?(*args)
        if args.size == 1 && args[0].is_a?(@klass)
          key = args[0].identifying_role_values
        else
          key = @klass.identifying_role_values(*args)
        end
        return @hash[key]
      end

      def []=(key, value)   #:nodoc:
        @hash[key] = value
      end

      def [](*args)
        @hash[*args]
      end

      def size
        @hash.size
      end

      def empty?
        @hash.size == 0
      end

      def each &b
        @hash.each &b
      end

      def map &b
        @hash.map &b
      end

      def detect &b
        r = @hash.detect &b
        r ? r[1] : nil
      end

      # Return an array of all the instances of this object_type
      def values
        @hash.values
      end

      # Return an array of the identifying role values arrays for all the instances of this object_type
      def keys
        @hash.keys
      end

      def delete_if(&b)   #:nodoc:
        @hash.delete_if &b
      end
    end
  end
end
