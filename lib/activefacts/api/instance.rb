#
#       ActiveFacts Runtime API
#       Instance (mixin module for instances of a ObjectType - a class with ObjectType mixed in)
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API
    # Every Instance of a ObjectType (A Value type or an Entity type) includes the methods of this module:
    module Instance
      # What constellation does this Instance belong to (if any):
      attr_reader :constellation

      def initialize(args = []) #:nodoc:
        unless (self.class.is_entity_type)
          begin
            super(*args)
          rescue TypeError => e
            if trace(:debug)
              p e; puts e.backtrace*"\n\t"; debugger; true
            end
          rescue ArgumentError => e
            e.message << " constructing a #{self.class}"
            raise
          end
        end
      end

      def is_a? klass
        super || self.class.supertypes_transitive.include?(klass)
      end

      # List entities which have an identifying role played by this object.
      def related_entities(indirectly = true, instances = [])
        # Check all roles of this instance
        self.class.all_role.each do |role_name, role|
          # If the counterpart role is not identifying for its object type, skip it
          next unless c = role.counterpart and c.is_identifying

          identified_instances = Array(self.send(role.getter))
          instances.concat(identified_instances)
          identified_instances.each do |instance|
            instance.related_entities(indirectly, instances) if indirectly
          end
        end
        instances
      end

      def instance_index
        @constellation.send(self.class.basename.to_sym)
      end

      # De-assign all functional roles and remove from constellation, if any.
      def retract
        return unless constellation = @constellation

        unless constellation.loggers.empty?
          # An object may have multiple identifiers, with potentially overlapping role sets
          # Get one copy of each role to use in asserting the instance
          if self.class.is_entity_type
            identifying_role_values = {}
            ([self.class]+self.class.supertypes_transitive).each do |klass|
              klass.identifying_role_names.zip(identifying_role_values(klass)).each do |name, value|
                identifying_role_values[name] = value
              end
            end
          else
            identifying_role_values = self
          end
        end

        # Delete from the constellation first, while we remember our identifying role values
        constellation.deindex_instance(self)
        instance_variable_set(@@constellation_variable_name ||= "@constellation", nil)

        # Now, for all roles (from this class and all supertypes), assign nil to all functional roles
        # The counterpart roles get cleared automatically.
        klasses = [self.class]+self.class.supertypes_transitive

        irvrvs = {}  # identifying_role_values by RoleValues
        self.class.all_role_transitive.each do |_, role|
          next unless role.counterpart and
            role.unique and
            !role.counterpart.unique and
            counterpart = send(role.getter)
          role_values = counterpart.send(role.counterpart.getter)
          irvrvs[role_values] = role_values.index_values(self)
        end

        # Nullify the counterpart role of objects we identify first, before damaging our identifying_role_values:
        klasses.each do |klass|
          klass.all_role.each do |role_name, role|
            next if role.unary?
            next if !(counterpart = role.counterpart).is_identifying
            next if role.fact_type.is_a?(TypeInheritanceFactType)

            counterpart_instances = send(role.getter)
            counterpart_instances.to_a.each do |counterpart_instance|
              # Allow nullifying non-mandatory roles, as long as they're not identifying.
              if counterpart.mandatory
                counterpart_instance.retract
              else
                counterpart_instance.send(counterpart.setter, nil, false)
              end
            end
          end
        end

        # Now deal with other roles:
        klasses.each do |klass|
          klass.all_role.each do |role_name, role|
            next if role.unary?
            counterpart = role.counterpart

            # Objects being created do not have to have non-identifying mandatory roles,
            # so we allow retracting to the same state.
            if role.unique
              next if role.fact_type.is_a?(TypeInheritanceFactType)
              i = send(role.getter)
              next unless i

              if (counterpart.unique)
                # REVISIT: This will incorrectly fail to propagate a key change for a non-mandatory role
                i.send(counterpart.setter, nil, false)
              else
                rv = i.send(role.counterpart.getter)
                rv.delete_instance(self, irvrvs[rv])

                if (rv.empty? && !i.class.is_entity_type)
                  i.retract if i.plays_no_role
                end

              end
              instance_variable_set(role.variable, nil)
            else
              # puts "Not removing role #{role_name} from counterpart RoleValues #{counterpart.name}"
              # Duplicate the array using to_a, as the RoleValues here will be modified as we traverse it:
              next if role.fact_type.is_a?(TypeInheritanceFactType)
              counterpart_instances = send(role.getter)
              counterpart_instances.to_a.each do |counterpart_instance|
                # This action deconstructs our RoleValues as we go:
                counterpart_instance.send(counterpart.setter, nil, false)
              end
              instance_variable_set(role.variable, nil)
            end
          end
        end

        constellation.loggers.each{|l| l.call(:retract, self.class, identifying_role_values) }

      end

      module ClassMethods #:nodoc:
        include ObjectType
        # Add Instance class methods here
      end
    end
  end
end
