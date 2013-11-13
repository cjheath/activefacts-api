#
#       ActiveFacts Runtime API
#       Custom exception classes
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.

module ActiveFacts
  module API
    class ActiveFactsException < StandardError
    end

    class SchemaException < ActiveFactsException
    end

    class RuntimeException < ActiveFactsException
    end

    class CrossVocabularyRoleException < SchemaException
      def initialize klass, vocabulary
        super "#{klass} must be an object type in #{vocabulary.name}"
      end
    end

    class InvalidEntityException < SchemaException
      def initialize klass
	super "#{klass.basename} may not be an entity type"
      end
    end

    class InvalidIdentificationException < SchemaException
      def initialize object_type, role, is_single
	msg =
	  if is_single
	    "#{object_type} has a single identifying role '#{role}' which is has_one, but must be one_to_one"
	  else
	    "#{object_type} has an identifying role '#{role}' which is one_to_one, but must be has_one"
	  end
	super msg
      end
    end

    class MissingIdentificationException < SchemaException
      def initialize klass
	super "You must list the roles which will identify #{klass.basename}"
      end
    end

    class InvalidObjectType < SchemaException
      def initialize vocabulary, klass, reason
	super "A constellation over #{vocabulary.name} cannot index instances of #{klass} because it #{reason}"
      end
    end

    class InvalidSupertypeException < SchemaException
    end

    class DuplicateRoleException < SchemaException
    end

    class UnrecognisedOptionsException < SchemaException
      def initialize declaration, instance, option_names
        super "Unrecognised options on declaration of #{declaration} #{instance}: #{option_names.inspect}"
      end
    end

    class RoleNotDefinedException < RuntimeException
      def initialize klass, role_name
        super "Role #{klass.basename}.#{role_name} is not defined"
      end
    end

    class UnexpectedIdentifyingValueException < RuntimeException
      def initialize object_type, identifying_role_names, extra_args
	super "#{object_type.basename} expects only (#{identifying_role_names*', '}) for its identifier, but you provided additional values #{extra_args.inspect}"
      end
    end

    class MissingMandatoryRoleValueException < RuntimeException
      def initialize klass, role
        super "A #{role.counterpart.object_type.basename} is required to satisfy the #{role.name.inspect} role of #{klass.basename}"
      end
    end

    class DuplicateIdentifyingValueException < RuntimeException
      def initialize(klass, role_name, value)
        super("Illegal attempt to assert #{klass.basename} having identifying value" +
              " (#{role_name} is #{value.verbalise})," +
              " when #{value.related_entities(false).map(&:verbalise).join(", ")} already exists")
      end
    end

    # When an existing object having multiple identification patterns is re-asserted, all the keys must match the existing object
    class TypeConflictException < RuntimeException
      def initialize(klass, supertype, key, existing)
	super "#{klass} cannot be asserted to have #{supertype} identifier #{key.inspect} because the existing object has #{existing.inspect}"
      end
    end

    # When a new entity is asserted, but a supertype identifier matches an existing object of a different type, type migration is implied but unfortunately is impossible in Ruby
    class TypeMigrationException < RuntimeException
      def initialize(klass, supertype, key)
	super "#{klass} cannot be asserted due to the prior existence of a conflicting #{supertype} identified by #{key.inspect}"
      end
    end

  end
end
