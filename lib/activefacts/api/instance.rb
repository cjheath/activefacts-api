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

      # If this instance's role is updated to the new value, does that cause a collision?
      # We need to check each superclass that has a different identification pattern
      def check_identification_change_legality(role, value)
        return unless @constellation && role.is_identifying
	return if @constellation.send(:instance_variable_get, :@suspend_duplicate_key_check)

	klasses = [self.class] + self.class.supertypes_transitive
	last_identity = nil
	last_irns = nil
	counterpart_class = role.counterpart ? role.counterpart.object_type : value.class
        duplicate = klasses.detect do |klass|
          next false unless klass.identifying_roles.include?(role)
	  irns = klass.identifying_role_names
	  if last_irns != irns
	    last_identity = identifying_role_values(klass)
	    role_position = irns.index(role.name)
	    last_identity[role_position] = value.identifying_role_values(counterpart_class)
	  end
	  @constellation.instances[klass][last_identity]
        end

	raise DuplicateIdentifyingValueException.new(self.class, role.name, value) if duplicate
      end

      # List entities which have an identifying role played by this object.
      def related_entities(indirectly = true, instances = [])
	# Check all roles of this instance
        self.class.roles.each do |role_name, role|
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
        # Delete from the constellation first, while we remember our identifying role values
        @constellation.deindex_instance(self) if @constellation

        # Now, for all roles (from this class and all supertypes), assign nil to all functional roles
        # The counterpart roles get cleared automatically.
	klasses = [self.class]+self.class.supertypes_transitive

	irvks = {}  # identifying_role_values by class
	klasses.each do |klass|
	  if !irvks[klass] and klass.roles.detect{|_, role| role.counterpart and !role.counterpart.unique and send(role.getter) }
	    # We will need the identifying_role_values for this role's object_type
	    irvks[klass] = identifying_role_values(klass)
	  end
	end

	klasses.each do |klass|
          klass.roles.each do |role_name, role|
            next if role.unary?
            counterpart = role.counterpart

	    # Objects being created do not have to have non-identifying mandatory roles,
	    # so we allow retracting to the same state.
            if role.unique
	      i = send(role.getter)
	      next unless i
	      if counterpart.is_identifying && counterpart.mandatory
		# We play a mandatory identifying role in i; so retract that (it'll clear our instance variable)
		i.retract
	      else
		if (counterpart.unique)
		  # REVISIT: This will incorrectly fail to propagate a key change for a non-mandatory role
		  i.send(counterpart.setter, nil, false)
		else
		  rv = i.send(role.counterpart.getter)
		  rv.delete_instance(self, irvks[role.object_type])
		end
	      end
	      instance_variable_set(role.variable, nil)
            else
              # puts "Not removing role #{role_name} from counterpart RoleValues #{counterpart.name}"
              # Duplicate the array using to_a, as the RoleValues here will be modified as we traverse it:
	      counterpart_instances = send(role.name)
	      counterpart_instances.to_a.each do |counterpart_instance|
		# These actions deconstruct the RoleValues as we go:
                if counterpart.is_identifying && counterpart.mandatory
                  counterpart_instance.retract
                else
                  counterpart_instance.send(counterpart.setter, nil, false)
                end
              end
	      instance_variable_set(role.variable, nil)
            end
          end
        end
      end

      module ClassMethods #:nodoc:
        include ObjectType
        # Add Instance class methods here
      end
    end
  end
end
