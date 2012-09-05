#
#       ActiveFacts Runtime API
#       InstanceIndex class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#

module ActiveFacts
  module API
    # FlatHash implements two different behaviors.
    #
    # It uses comparable hash keys which allows comparison of nil values and
    # it makes traversing methods of the hash work like an array.
    #
    # Example:
    # flat_hash.each { |v| p v }
    # # instead of
    # hash.each { |k, v| p v }
    # # while keeping behaviors such as
    # flat_hash['hello'] = 'world'
    module FlatHash
      def []=(key, value)
        @hash[ComparableHashKey.new(key)] = value
      end

      def [](key)
        @hash[ComparableHashKey.new(key)]
      end

      def keys
        @hash.keys.map { |key| key.value }
      end

      def each(&block)
        if block.arity < 2
          @hash.each { |_,v| block.call(v) }
        else
          @hash.each(&block)
        end
      end
    end
  end
end
