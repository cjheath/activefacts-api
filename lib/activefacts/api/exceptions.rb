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
      def initialize(klass, role_name, value)
        super("Illegal attempt to assert #{klass.basename} having identifying value" +
              " (#{role_name} is #{value.verbalise})," +
              " when #{value.related_entities(false).map(&:verbalise).join(", ")} already exists")
      end
    end

    # When an existing object having multiple identification patterns is re-asserted, all the keys must match the existing object
    class TypeConflictException < ActiveFactsRuntimeException
      def initialize(klass, supertype, key, existing)
	super "#{klass} cannot be asserted to have #{supertype} identifier #{key.inspect} because the existing object has #{existing.inspect}"
      end
    end

    # When a new entity is asserted, but a supertype identifier matches an existing object of a different type, type migration is implied but unfortunately is impossible in Ruby
    class TypeMigrationException < ActiveFactsRuntimeException
      def initialize(klass, supertype, key)
	super "#{klass} cannot be asserted due to the prior existence of a conflicting #{supertype} identified by #{key.inspect}"
      end
    end

  end
end
