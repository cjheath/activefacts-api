#
#       ActiveFacts Runtime API
#       Instance (mixin module for instances of a ObjectType - a class with ObjectType mixed in)
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
# Instance methods are extended into all instances, whether of value or entity types.
#
module ActiveFacts
  module API
    # Every Instance of a ObjectType (A Value type or an Entity type) includes the methods of this module:
    module Instance
      # What constellation does this Instance belong to (if any):
      attr_accessor :constellation

      def initialize(args = []) #:nodoc:
        unless (self.class.is_entity_type)
          begin
            super(*args)
          rescue ArgumentError => e
            e.message << " constructing a #{self.class}"
            raise
          end
        end
      end

      # Detect inconsistencies within constellation if this entity was updated
      # with the specified role/value pair.
      def detect_inconsistencies(role, value)
        if duplicate_identifying_values?(role, value)
          exception_data = {
            :value => value,
            :role  => role,
            :class => self.class
          }

          raise DuplicateIdentifyingValueException.new(exception_data)
        end
      end

      # Checks if instance have duplicate values within its constellation.
      #
      # Only works on identifying roles.
      def duplicate_identifying_values?(role, value)
        @constellation && role.is_identifying && !is_unique?(:role => role, :value => value)
      end

      # Checks if instance would still be unique if it was updated with
      # args.
      #
      # args should be a hash containing the role and value to update
      # and the name of the identifying value as the key.
      #
      # For example, if a Person is identified by name and family_name:
      # updated_values = { :name => "John" }
      # Would merge this hash with the one defining the current instance
      # and verify in our constellation if it exists.
      #
      # The uniqueness of the entity will also be checked within its supertypes.
      #
      # An Employee -subtype of a Person- identified by its employee_id would
      # collide with a Person if it has the same name. But `name` may not be
      # an identifying value for the Employee identification scheme.
      def is_unique?(args)
        duplicate = ([self.class] + self.class.supertypes_transitive).detect do |klass|
          old_identity = identity_by(klass)
          if klass.identifying_roles.include?(args[:role])
            new_identity = old_identity.merge(args[:role].getter => args[:value])
            @constellation.instances[klass].include?(new_identity)
          else
            false
          end
        end

        !duplicate
      end

      # List entities which reference the current one.
      #
      # Once an entity is found, it will also search for
      # related entities of this instance.
      def related_entities(instances = [])
        self.class.roles.each do |role_name, role|
          instance_index_counterpart(role).each do |irv, instance|
            if instance.class.is_entity_type && instance.is_identified_by?(self)
              if !instances.include?(instance)
                instances << instance
                instance.related_entities(instances)
              end
            end
          end
        end
        instances
      end

      # Determine if entity is an identifying value
      # of the current instance.
      def is_identified_by?(entity)
        self.class.identifying_roles.detect do |role|
          send(role.getter) == entity
        end
      end

      def instance_index
        @constellation.send(self.class.basename.to_sym)
      end

      def instance_index_counterpart(role)
        if @constellation && role.counterpart
          @constellation.send(role.counterpart.object_type.basename.to_sym)
        else
          []
        end
      end

      # Verbalise this instance
      # REVISIT: Should it raise an error if it was not redefined ?
      def verbalise
        # REVISIT: Should it raise an error if it was not redefined ?
        # This method should always be overridden in subclasses
      end

      # De-assign all functional roles and remove from constellation, if any.
      def retract
        # Delete from the constellation first, while it remembers our identifying role values
        @constellation.__retract(self) if @constellation

        # Now, for all roles (from this class and all supertypes), assign nil to all functional roles
        # The counterpart roles get cleared automatically.
        ([self.class]+self.class.supertypes_transitive).each do |klass|
          klass.roles.each do |role_name, role|
            next if role.unary?
            counterpart = role.counterpart
            if role.unique
              # puts "Nullifying mandatory role #{role.name} of #{role.object_type.name}" if counterpart.mandatory

              send role.setter, nil
            else
              # puts "Not removing role #{role_name} from counterpart RoleValues #{counterpart.name}"
              # Duplicate the array using to_a, as the RoleValues here will be modified as we traverse it:
              send(role.name).to_a.each do |v|
                if counterpart.is_identifying
                  v.retract
                else
                  v.send(counterpart.setter, nil)
                end
              end
            end
          end
        end
      end

      module ClassMethods #:nodoc:
        include ObjectType
        # Add Instance class methods here
      end

      def Instance.included other #:nodoc:
        other.send :extend, ClassMethods
      end
    end
  end
end
