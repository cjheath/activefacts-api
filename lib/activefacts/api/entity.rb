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

      # Assign the identifying roles to initialise a new Entity instance.
      # The role values are asserted in the constellation first, so you
      # can pass bare values (array, string, integer, etc) for any role
      # whose instances can be constructed using those values.
      #
      # A value must be provided for every identifying role, but if the
      # last argument is a hash, they may come from there.
      #
      # If a supertype (including a secondary supertype) has a different
      # identifier, the identifying roles must be provided in the hash.
      #
      # Any additional (non-identifying) roles in the hash are ignored
      def initialize(*args)
        klass = self.class
        while klass.identification_inherited_from
          klass = klass.superclass
        end

        if args[-1].respond_to?(:has_key?) && args[-1].has_key?(:constellation)
          @constellation = args.pop[:constellation]
        end
        hash = args[-1].is_a?(Hash) ? args.pop.clone : nil

        # Pass just the hash, if there is one, else no arguments:
        super(*(hash ? [hash] : []))

        # Pick any missing identifying roles out of the hash if possible:
        irns = klass.identifying_role_names
        while hash && args.size < irns.size
          value = hash[role = irns[args.size]]
          hash.delete(role)
          args.push value
        end

        # If one arg is expected but more are passed, they might be the
        # args for the object that plays a single identifying role:
        args = [args] if klass.identifying_role_names.size == 1 && args.size > 1

        # This occur when there are too many args passed, or too few
        # and no hash. Otherwise the missing ones will be nil.
        raise "Wrong number of parameters to #{klass}.new, " +
            "expect (#{klass.identifying_role_names*","}) " +
            "got (#{args.map{|a| a.to_s.inspect}*", "})" if args.size != klass.identifying_role_names.size

        # Assign the identifying roles in order. Any other roles will be assigned by our caller
        klass.identifying_role_names.zip(args).each do |role_name, value|
          role = self.class.roles(role_name)
          send(role.setter, value)
        end
      end

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
        self.class.identifying_role_names.map{|role_name|
            instance_variable_get("@#{role_name}")
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

      # Return the array of the values of this entity instance's identifying roles
      def identifying_role_values
        self.class.identifying_role_names.map do |role_name|
          send(role_name).identifying_role_values
        end
      end

      # Identifying role values in a hash form.
      def identity_as_hash
        identity_by(self.class)
      end

      # Clones identity.
      #
      # Cloning an entity identity means copying its class identifying values and also its supertypes identifying
      # values.
      def clone_identity
        self.class.supertypes_transitive.inject(identity_as_hash) do |roles_hash, supertype|
          roles_hash.merge!(identity_by(supertype))
        end
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
          if superclass.is_entity_type
            if superclass.roles.has_key?(role_name)
              superclass.roles[role_name]
            else
              superclass.find_inherited_role(role_name)
            end
          else
            false
          end
        end

        # Convert the passed arguments into an array of raw values (or arrays of values, transitively)
        # that identify an instance of this Entity type:
        def identifying_role_values(*args)
          irns = identifying_role_names

          # If the single arg is an instance of the correct class or a subclass,
          # use the instance's identifying_role_values
          has_hash = args[-1].is_a?(Hash)
          if (args.size == 1+(has_hash ? 1 : 0) and (arg = args[0]).is_a?(self))
            # With a secondary supertype or a subtype having separate identification,
            # we would get the wrong identifier from arg.identifying_role_values:
            return irns.map do |role_name|
                # Use the identifier for the class expected, not the actual:
                value = arg.send(role_name)
                value && arg.class.roles(role_name).counterpart_object_type.identifying_role_values(value)
              end
          end

          args, arg_hash = ActiveFacts::extract_hash_args(irns, args)

          if args.size > irns.size
            raise "#{basename} expects only (#{irns*', '}) for its identifier, but you provided the extra values #{args[irns.size..-1].inspect}"
          end

          role_args = irns.map{|role_sym| roles(role_sym)}.zip(args)
          role_args.map do |role, arg|
            next !!arg unless role.counterpart  # Unary
            if arg.is_a?(role.counterpart.object_type)              # includes secondary supertypes
              # With a secondary supertype or a type having separate identification,
              # we would get the wrong identifier from arg.identifying_role_values:
              next role.counterpart_object_type.identifying_role_values(arg)
            end
            if arg == nil # But not false
              if role.mandatory
                raise "You must provide a #{role.counterpart.object_type.name} to identify a #{basename}"
              end
            else
              role.counterpart_object_type.identifying_role_values(*arg)
            end
          end
        end

        # REVISIT: This method should verify that all identifying roles (including
        # those required to identify any superclass) are present (if mandatory)
        # and are unique... BEFORE it creates any new object(s)
        # This is a hard problem because it's recursive.
        def assert_instance(constellation, args) #:nodoc:
          # Build the key for this instance from the args
          # The key of an instance is the value or array of keys of the identifying values.
          # The key values aren't necessarily present in the constellation, even after this.
          key = identifying_role_values(*args)

          # Find and return an existing instance matching this key
          instances = constellation.instances[self]   # All instances of this class in this constellation
          instance = instances[key]
          # REVISIT: This ignores any additional attribute assignments
          if instance
            raise "Additional role values are ignored when asserting an existing instance" if args[-1].is_a? Hash and !args[-1].empty?
            return instance, key      # A matching instance of this class
          end

          # Now construct each of this object's identifying roles
          irns = identifying_role_names
          @created_instances ||= []

          has_hash = args[-1].is_a?(Hash)
          if args.size == 1+(has_hash ? 1 : 0) and args[0].is_a?(self)
            # We received a single argument of a compatible type
            # With a secondary supertype or a type having separate identification,
            # we would get the wrong identifier from arg.identifying_role_values:
            key = 
              values = identifying_role_values(args[0])
            values = values + [arg_hash = args.pop] if has_hash
          else
            args, arg_hash = ActiveFacts::extract_hash_args(irns, args)
            roles_and_values = irns.map{|role_sym| roles(role_sym)}.zip(args)
            key = []    # Gather the actual key (AutoCounters are special)
            values = roles_and_values.map do |role, arg|
                if role.unary?
                  # REVISIT: This could be absorbed into a special counterpart.object_type.assert_instance
                  value = role_key = arg ? true : arg   # Preserve false and nil
                elsif !arg
                  value = role_key = nil
                else
                  if role.counterpart.object_type.is_entity_type
                    add = !constellation.send(role.counterpart.object_type.basename.to_sym).include?([arg])
                  else
                    add = !constellation.send(role.counterpart.object_type.basename.to_sym).include?(arg)
                  end
                  value, role_key = role.counterpart.object_type.assert_instance(constellation, Array(arg))
                  @created_instances << [role.counterpart, value] if add
                end
                key << role_key
                value
              end
            values << arg_hash if arg_hash and !arg_hash.empty?
          end

          #trace :assert, "Constructing new #{self} with #{values.inspect}" do
          values << { :constellation => constellation }
          instance = new(*values)
          #end

          # Now assign any extra args in the hash which weren't identifiers (extra identifiers will be assigned again)
          (arg_hash ? arg_hash.entries : []).each do |role_name, value|
            role = roles(role_name)

            if !instance.instance_index_counterpart(role).include?(value)
              @created_instances << [role, value]
            end
            instance.send(role.setter, value)
          end

          return *index_instance(instance, key, irns)

        rescue DuplicateIdentifyingValueException
          @created_instances.each do |role, v|
            v.retract if v
          end
          @created_instances = []
          raise
        end

        def index_instance(instance, key = nil, key_roles = nil) #:nodoc:
          # Derive a new key if we didn't receive one or if the roles are different:
          unless key && key_roles && key_roles == identifying_role_names
            key = (key_roles = identifying_role_names).map do |role_name|
              instance.send role_name
            end
            raise "You must pass values for #{key_roles.inspect} to identify a #{self.name}" if key.compact == []
          end

          # Index the instance for this class in the constellation
          instances = instance.constellation.instances[self]
          instances[key] = instance

          # Index the instance for each supertype:
          supertypes.each do |supertype|
            supertype.index_instance(instance, key, key_roles)
          end

          return instance, key
        end

        # A object_type that isn't a ValueType must have an identification scheme,
        # which is a list of roles it plays. The identification scheme may be
        # inherited from a superclass.
        def identified_by(*args) #:nodoc:
          raise "You must list the roles which will identify #{self.basename}" unless args.size > 0

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
          vocabulary.__add_object_type(other)
        end

        # verbalise this object_type
        def verbalise
          "#{basename} is identified by #{identifying_role_names.map{|role_sym| role_sym.to_s.camelcase}*" and "};"
        end
      end

      def Entity.included other #:nodoc:
        other.send :extend, ClassMethods

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
