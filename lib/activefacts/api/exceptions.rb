#
#       ActiveFacts Runtime API
#       Custom exception classes
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.

module ActiveFacts
  module API
    class DuplicateIdentifyingValueException < StandardError
      def initialize(desc)
        verbalised_entities = desc[:value].related_entities.map do |entity, role_obj, role_value|
          entity.verbalise
        end
        super("Illegal attempt to assert #{desc[:class].basename} having identifying value" +
              " (#{desc[:role].name} is #{desc[:value].verbalise})," +
              " when #{verbalised_entities} already exists")
      end
    end
  end
end
