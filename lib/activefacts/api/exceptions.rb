#
#       ActiveFacts Runtime API
#       Custom exception classes
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.

module ActiveFacts
  module API
    class DuplicateIdentifyingValueException < Exception
      def initialize(desc)
        super("#{desc[:class].basename}: Illegal attempt to change an identifying value (Duplicate)" +
              " (#{desc[:role].setter} used with #{desc[:value].verbalise}," +
              " already used by [#{desc[:value].related_entities.map(&:verbalise).join(", ")}])")
      end
    end
  end
end