#
#       ActiveFacts Runtime API
#       Custom exception classes
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.

module ActiveFacts
  module API
    class ActiveFactsException < StandardError
    end

    class ActiveFactsSchemaException < ActiveFactsException
    end

    class ActiveFactsRuntimeException < ActiveFactsException
    end

    class CrossVocabularyRoleException < ActiveFactsSchemaException
      def initialize klass, vocabulary
        super "#{klass} must be an object type in #{vocabulary.name}"
      end
    end

    class RoleNotDefinedException < ActiveFactsRuntimeException
      def initialize klass, role_name
        super "Role #{klass.basename}.#{role_name} is not defined"
      end
    end

    class MissingMandatoryRoleValueException < ActiveFactsRuntimeException
      def initialize klass, role
        super "A #{role.counterpart.object_type.basename} is required to satisfy the #{role.name.inspect} role of #{klass.basename}"
      end
    end

    class DuplicateIdentifyingValueException < ActiveFactsRuntimeException
      def initialize(desc)
        super("Illegal attempt to assert #{desc[:class].basename} having identifying value" +
              " (#{desc[:role].name} is #{desc[:value].verbalise})," +
              " when #{desc[:value].related_entities.map(&:verbalise).join(", ")} already exists")
      end
    end
  end
end
