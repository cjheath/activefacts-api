#
#       ActiveFacts Runtime API
#       Entity class (a mixin module for the class Class)
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API
    # An Entity type is any ObjectType that isn't a value type.
    # All Entity types must have an identifier made up of one or more roles.
    module Entity
      include Instance

    private
      # Initialise a new Entity instance.
      #
      # arg_hash contains full-normalised and valid keys for the counterpart
      # role values.
      #
      # This instance and its supertypes might have distinct identifiers,
      # and none of the identifiers may already exist in the constellation.
      #
      # Pick out the identifying roles and assert the counterpart instances
      # to assign as the new object's role values.
      #
      # The identifying roles of secondary supertypes must also be assigned
      # here.
      def initialize(arg_hash)
	raise ArgumentError.new("#{self}.new expects a hash. You should use assert instead anyhow") unless arg_hash.is_a?(Hash)

        super(arg_hash)

        unless (klass = self.class).identification_inherited_from
	  irns = klass.identifying_role_names
	  irns.each do |role_name|
	    role = klass.roles(role_name)
	    key = arg_hash.delete(role_name)
	    value =
	      if key == nil
		nil
	      elsif role.unary?
		(key && true)	# Preserve nil and false
	      else
		role.counterpart.object_type.assert_instance(constellation, Array(key))
	      end

	    begin
	      @constellation.send(:instance_variable_set, :@suspend_duplicate_key_check, true)
	      send(role.setter, value)
	      @constellation.send(:instance_variable_set, :@suspend_duplicate_key_check, false)
#	    rescue NoMethodError => e
#	      raise settable_roles_exception(e, role_name)
	    end
	    # instance_variable_set(role.setter, value)
	  end
        end
      end

=begin
# I forget how it was possible to reproduce this exception,
# so I can't get code coverage over it. It might not be still possible,
# but I can't be sure so I'll leave the code here for now.
      def settable_roles_exception e, role_name
        n = NoMethodError.new(
          "You cannot assert a #{self.class} until you define #{role_name}.\n" +
          "Settable roles are #{settable_roles*', '}.\n" +
          (if self.class.vocabulary.delayed.empty?
            ''
          else
            "Please define these object types: #{self.class.vocabulary.delayed.keys.sort*', '}\n"
          end
          )
        )
        n.set_backtrace(e.backtrace)
        n
      end

      def settable_roles
        ([self.class]+self.class.supertypes_transitive).
          map do |k|
            k.roles.
              map do |name, role|
                role.unique ? name : nil
              end.
              compact
            end.
          flatten
      end
=end

    public
      def inspect #:nodoc:
        inc = constellation ? " in #{constellation.inspect}" : ""
        # REVISIT: Where there are one-to-one roles, this cycles
        irnv = self.class.identifying_role_names.map do |role_name|
          "@#{role_name}="+send(role_name).inspect
        end
        "\#<#{self.class.basename}:#{object_id}#{inc} #{ irnv*' ' }>"
      end

      # When used as a hash key, the hash key of this entity instance is calculated
      # by hashing the values of its identifying roles
      def hash
        self.class.identifying_roles.map{|role|
            instance_variable_get(role.variable)
          }.inject(0) { |h,v|
            h ^= v.hash
            h
          }
      end

      # When used as a hash key, this entity instance is compared with another by
      # comparing the values of its identifying roles
      def eql?(other)
        if self.class == other.class
          identity_as_hash == other.identity_as_hash
        else
          false
        end
      end

      # Verbalise this entity instance
      def verbalise(role_name = nil)
        irnv = self.class.identifying_role_names.map do |role_sym|
            value = send(role_sym)
            identifying_role_name = self.class.roles(role_sym).name.to_s.camelcase
            value ? value.verbalise(identifying_role_name) : "nil"
          end
        "#{role_name || self.class.basename}(#{ irnv*', ' })"
      end

      # Return the array of the values of this instance's identifying roles
      def identifying_role_values(klass = self.class)
        klass.identifying_roles.map do |role|
          value = send(role.name)
	  counterpart_class = role.counterpart && role.counterpart.object_type
	  value.identifying_role_values(counterpart_class)
	end
      end

      # Identifying role values in a hash form.
      def identity_as_hash
        identity_by(self.class)
      end

      # Identifying role values in a hash form by class (entity).
      #
      # Subtypes may have different identifying roles compared to their supertype, and therefore, a subtype entity
      # may be identified differently if compared to one of its supertype.
      def identity_by(klass)
        roles_hash = {}
        klass.identifying_roles.each do |role|
          roles_hash[role.getter] = send(role.getter)
        end
        roles_hash
      end

      # This role is identifying, so if is changed, not only
      # must the current object be re-indexed, but also entities
      # identified by this entity.  Save the current key and
      # class for each such instance.
      # This function is transitive!
      def analyse_impacts role
	impacts = []

	# Consider the object itself and all its supertypes
	([self.class]+self.class.supertypes_transitive).map do |supertype|
	  next unless supertype.identifying_roles.include?(role)

	  old_key = identifying_role_values(supertype)
	  # puts "Need to reindex #{self.class} as #{supertype} from #{old_key.inspect}"
	  impacts << [supertype, self, old_key]
	end

	# Now consider objects whose identifiers include this object.
	# Find our roles in those identifiers first.
	impacted_roles = []
	self.class.all_roles.each do |n, role|
	  if role.counterpart && role.counterpart.is_identifying
	    # puts "Changing #{role.inspect} affects #{role.inspect}"
	    impacted_roles << role
	  end
	end

	impacted_roles.each do |role|
	  affected_instances = Array(instance_variable_get(role.variable))
	  # puts "considering #{affected_instances.size} #{role.object_type.name} instances that include #{role.inspect}: #{affected_instances.map(&:identifying_role_values).inspect}"
	  affected_instances.each do |counterpart|
	    impacts.concat(counterpart.analyse_impacts(role.counterpart))
	  end
	end
	impacts
      end

      def apply_impacts impacts
	impacts.each do |klass, entity, old_key|
	  instance_index = entity.constellation.instances[klass]
	  new_key = entity.identifying_role_values(klass)
	  # puts "Reindexing #{klass} from #{old_key.inspect} to #{new_key.inspect}"

	  if new_key != old_key
	    instance_index.delete(old_key)
	    instance_index[new_key] = entity
	  end
	end
      end

      # All classes that become Entity types receive the methods of this class as class methods:
      module ClassMethods
        include Instance::ClassMethods

        attr_accessor :identification_inherited_from
        attr_accessor :overrides_identification_of
        attr_accessor :created_instances

        # Return the array of Role objects that define the identifying relationships of this Entity type:
        def identifying_role_names
          if identification_inherited_from
            superclass.identifying_role_names
          else
            @identifying_role_names ||= []
          end
        end

        def identifying_roles
          # REVISIT: Should this return nil if identification_inherited_from?
          @identifying_roles ||=
            identifying_role_names.map do |role_name|
              role = roles[role_name] || find_inherited_role(role_name)
              role
            end
        end

        def find_inherited_role(role_name)
          if !superclass.is_entity_type
            false
          elsif superclass.roles.has_key?(role_name)
            superclass.roles[role_name]
          else
            superclass.find_inherited_role(role_name)
          end
        end

	def check_supertype_identifiers_match instance, arg_hash
	  supertypes_transitive.each do |supertype|
	    supertype.identifying_roles.each do |role|
	      next unless arg_hash.include?(role.name)	  # No contradiction here
	      new_value = arg_hash[role.name]
	      existing_value = instance.send(role.name.to_sym)

	      # Quick check for an exact match:
	      counterpart_class = role.counterpart && role.counterpart.object_type
	      next if existing_value == new_value or existing_value.identifying_role_values(counterpart_class) == new_value

	      # Coerce the new value to identifying values for the counterpart role's type:
	      role = supertype.roles(role.name)
	      new_key = role.counterpart.object_type.identifying_role_values(instance.constellation, [new_value])
	      # REVISIT: Check that the next line actually gets hit, otherwise strip it out
	      next if existing_value == new_key	  # This can happen when the counterpart is a value type

	      existing_key = existing_value.identifying_role_values(counterpart_class)
	      next if existing_key == new_key
	      raise TypeConflictException.new(basename, supertype, new_key, existing_key)
	    end
	  end
	end

	# all its candidate keys must match those from the arg_hash.
	def check_no_supertype_instance_exists constellation, arg_hash
	  supertypes_transitive.each do |supertype|
	    key = supertype.identifying_role_values(constellation, [arg_hash])
	    if constellation.instances[supertype][key]
	      raise TypeMigrationException.new(basename, supertype, key)
	    end
	  end
	end

	# This method receives an array (possibly including a trailing arguments hash)
	# from which the values of identifying roles must be coerced. Note that when a
	# value which is not the corrent class is received, we recurse to ask that class
	# to coerce what we *do* have.
	# The return value is an array of (and arrays of) raw values, not object instances.
	#
	# No new instances may be asserted, nor may any roles of objects in the constellation be changed
	def identifying_role_values(constellation, args)
          irns = identifying_role_names

	  # Normalise positional arguments into an arguments hash (this changes the passed parameter)
	  arg_hash = args[-1].is_a?(Hash) ? args.pop : {}

	  # If the first parameter is an object of type self, its
	  # identifying roles provide any values missing from the array/hash.
	  if args[0].is_a?(self)
	    proto = args.shift
	  end

	  # Following arguments provide identifying values in sequence; put them into the hash:
	  irns.each do |role_name|
	    break if args.size == 0
	    arg_hash[role_name] = args.shift
	  end

	  # Complain if we have left-over arguments
	  if args.size > 0
            raise UnexpectedIdentifyingValueException.new(self, irns, args)
	  end

	  # The arg_hash will be used to construct a new instance, if necessary
	  args.push(arg_hash)

	  irns.map do |role_name|
	    roles(role_name)
	  end.map do |role|
	    if arg_hash.include?(n = role.name)	  # Do it this way to avoid problems where nil or false is provided
	      value = arg_hash[n]
	      next (value && true) if (role.unary?)
	      if value
		klass = role.counterpart.object_type
		value = klass.identifying_role_values(constellation, Array(value))
	      end
	    elsif proto
	      value = proto.send(n)
	      counterpart_class = role.counterpart && role.counterpart.object_type
	      value = value.identifying_role_values(counterpart_class)
	      arg_hash[n] = value # Save the value for making a new instance
	      next value if (role.unary?)
	    else
	      value = nil
	    end

	    raise MissingMandatoryRoleValueException.new(self, role) if value.nil? && role.mandatory

	    value
	  end
	end

	def assert_instance(constellation, args)
	  key = identifying_role_values(constellation, args)

	  # The args is now normalized to an array containing a single Hash element
	  arg_hash = args[-1]

	  # Find or make an instance of the class:
          instance_index = constellation.instances[self]   # All instances of this class in this constellation
	  instance = constellation.has_candidate(self, key) || instance_index[key]
	  if (instance)
	    # Check that all assertions about supertype keys are non-contradictory
	    check_supertype_identifiers_match(instance, arg_hash)
	  else
	    # Check that no instance of any supertype matches the keys given
	    check_no_supertype_instance_exists(constellation, arg_hash)

	    instance = new_instance(constellation, arg_hash)
	    constellation.candidate(instance)
	  end

	  # Assign any extra roles that may have been passed.
	  # An exception here leaves the object indexed,
	  # but without the offending role (re-)assigned.
	  arg_hash.each do |k, v|
	    role = instance.class.roles(k)
	    unless role.is_identifying && role.object_type == self
	      value =
		if v == nil
		  nil
		elsif role.unary?
		  (v && true)	# Preserve nil and false
		else
		  role.counterpart.object_type.assert_instance(constellation, Array(v))
		end
	      instance.send(:"#{k}=", value)
	    end
	  end

	  instance
	end

        def index_instance(constellation, instance) #:nodoc:
	  # Index the instance in the constellation's InstanceIndex for this class:
	  instance_index = constellation.instances[self]
	  key = instance.identifying_role_values(self)
	  instance_index[key] = instance

          # Index the instance for each supertype:
	  supertypes.each do |supertype|
	    supertype.index_instance(constellation, instance)
	  end

	  instance
	end

        # A object_type that isn't a ValueType must have an identification scheme,
        # which is a list of roles it plays. The identification scheme may be
        # inherited from a superclass.
        def identified_by(*args) #:nodoc:
          options = (args[-1].is_a?(Hash) ? args.pop : {})
          options.each do |key, value|
	    raise UnrecognisedOptionsException.new('EntityType', basename, key) unless respond_to?(key)
            send(key, value)
          end

          raise MissingIdentificationException.new(self) unless args.size > 0

          # Catch the case where we state the same identification as our superclass:
          inherited_role_names = identifying_role_names
          if !inherited_role_names.empty?
            self.overrides_identification_of = superclass
            while from = self.overrides_identification_of.identification_inherited_from
              self.overrides_identification_of = from
            end
          end
          return if inherited_role_names == args
          self.identification_inherited_from = nil

          # @identifying_role_names here are the symbols passed in, not the Role
          # objects we should use.  We'd need late binding to use Role objects...
          @identifying_role_names = args
        end

        def inherited(other) #:nodoc:
          other.identification_inherited_from = self
          subtypes << other unless subtypes.include? other
	  TypeInheritanceFactType.new(self, other)
          vocabulary.__add_object_type(other)
        end

        # verbalise this object_type
        def verbalise
          "#{basename} is identified by #{identifying_role_names.map{|role_sym| role_sym.to_s.camelcase}*" and "};"
        end
      end

      def self.included other #:nodoc:
        other.send :extend, ClassMethods

	def other.new_instance constellation, *args
	  instance = allocate
	  instance.instance_variable_set(@@constellation_variable_name ||= "@constellation", constellation)
	  instance.send(:initialize, *args)
	  instance
	end

        # Register ourselves with the parent module, which has become a Vocabulary:
        vocabulary = other.modspace
        unless vocabulary.respond_to? :object_type  # Extend module with Vocabulary if necessary
          vocabulary.send :extend, Vocabulary
        end
        vocabulary.__add_object_type(other)
      end
    end
  end
end
