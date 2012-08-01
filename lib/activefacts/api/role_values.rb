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

      def_delegators :@a, :each, :size, :empty?, :-

      def initialize
        @a = []
      end

      def +(a)
        @a.+(a.is_a?(RoleValues) ? [a] : a)
      end

      def single
        size > 1 ? nil : @a[0]
      end

      def update(old, value)
        @a.delete(old) if old
        @a << value if value
      end

      def verbalise
        "[#{@a.map(&:verbalise).join(", ")}]"
      end
    end

  end
end
