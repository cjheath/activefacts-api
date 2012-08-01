#
#       ActiveFacts Runtime API
#       Custom exception classes
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.

module ActiveFacts
  module API
    class DuplicateIdentifyingValueException < StandardError
      def initialize(desc)
        super("Illegal attempt to assert #{desc[:class].basename} having identifying value" +
              " (#{desc[:role].name} is #{desc[:value].verbalise})," +
              " when #{desc[:value].related_entities.map(&:verbalise).join(", ")} already exists")
      end
    end
  end
end
