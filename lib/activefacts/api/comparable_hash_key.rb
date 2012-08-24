#
#       ActiveFacts Runtime API
#       InstanceIndex class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#

module ActiveFacts
  module API

    # ComparableHashKey provides a way to compare hashes with nil values.
    class ComparableHashKey

      # Key value
      attr_reader :value

      # Initialize an instance index key base on a hash.
      def initialize(hash)
        @value = flatten_key(hash)
      end

      # Compare an instance index key with another.
      #
      # Keys containing nil values will be compared using their string
      # representation. (see inspect)
      def <=>(other)
        if !contains_nil?(@value) && !contains_nil?(other.value)
          result = @value <=> other.value rescue nil
          if result.nil?
            result = @value.inspect <=> other.value.inspect
          end
          result
        else
          @value.inspect <=> other.value.inspect
        end
      end

      # Checks if arr contains a nil value.
      def contains_nil?(arr)
        if arr.class.ancestors.include?(Array)
          arr.any? do |el|
            if el.nil?
              true
            else
              contains_nil?(el)
            end
          end
        else
          arr.nil?
        end
      end

      def ==(other)
        @value == other.value
      end

      def eql?(other)
        if self.class == other.class
          self == other
        else
          false
        end
      end

      def hash
        @value.hash
      end

      private
      # Any entity contained in `key` will be changed into its identifying role
      # values.
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