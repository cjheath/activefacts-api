#
#       ActiveFacts Runtime API
#       Constellation class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#

module ActiveFacts
  module API      #:nodoc:
    # A Constellation is a population of instances of the ObjectType classes of a Vocabulary.
    # Every object_type class is either a Value type or an Entity type.
    #
    # Value types are uniquely identified by their value, and a constellation will only
    # ever have a single instance of a given value of that class.
    #
    # Entity instances are uniquely identified by their identifying roles, and again, a
    # constellation will only ever have a single entity instance for the values of those
    # identifying roles.
    #
    # As a result, you cannot "create" an object in a constellation - you merely _assert_
    # its existence. This is done using method_missing; @constellation.Thing(3) creates
    # an instance (or returns the existing instance) of Thing identified by the value 3.
    # You can also use the populate() method to apply a block of assertions.
    #
    # You can instance##retract any instance, and that removes it from the constellation (will
    # delete it from the database when the constellation is saved), and nullifies any
    # references to it.
    #
    # A Constellation may or not be valid according to the vocabulary's constraints,
    # but it may also represent a portion of a larger population (a database) with
    # which it may be merged to form a valid population. In other words, an invalid
    # Constellation may be invalid only because it lacks some of the facts.
    #
    class Constellation
      attr_reader :vocabulary

      # Create a new empty Constellation over the given Vocabulary
      def initialize(vocabulary, options = {})
        @vocabulary = vocabulary
        @options = options
      end

      def assert(klass, *args)
        with_candidates do
          klass.assert_instance self, args
        end
      end

      # Delete instances from the constellation, nullifying (or cascading) the roles each plays
      def retract(*instances)
        Array(instances).each do |i|
          i.retract
        end
        self
      end

      # Evaluate assertions against the population of this Constellation
      def populate &block
        instance_eval(&block)
        self
      end

      # If a missing method is the name of a class in the vocabulary module for this constellation,
      # then we want to access the collection of instances of that class, and perhaps assert new ones.
      # With no parameters, return the collection of all instances of that object_type.
      # With parameters, assert an instance of the object_type identified by the values passed as args.
      def method_missing(m, *args, &b)
        klass = @vocabulary.const_get(m)
        if invalid_object_type klass
          super
        else
          define_class_accessor m, klass
          send(m, *args, &b)
        end
      end

      def define_class_accessor m, klass
        singleton_class.
          send(:define_method, m) do |*args|
            if args.size == 0
              # Return the collection of all instances of this class in the constellation:
              instances[klass]
            else
              # Assert a new ground fact (object_type instance) of the specified class, identified by args:
              assert(klass, *args)
            end
        end
      end

      def inspect #:nodoc:
        total = instances.values.map(&:size).inject(:+) || 0
        "Constellation:#{object_id} over #{@vocabulary.name} with #{total}/#{instances.size}"
      end

      # Loggers is an array of callbacks
      def loggers
        @loggers ||= []
      end

      def invalid_object_type klass
        case
        when !klass.is_a?(Class)
          'is not a Class'
        when klass.modspace != @vocabulary
          "is defined in #{klass.modspace}, not #{@vocabulary.name}"
        when !klass.respond_to?(:assert_instance)
          "is not declared as an object type"
        else
          nil
        end
      end

      # "instances" is an index (keyed by the Class object) of indexes to instances.
      # Each instance is indexed for every supertype it has (including multiply-inherited ones).
      # The method_missing definition supports the syntax: c.MyClass.each{|k, v| ... }
      def instances
        @instances ||= Hash.new do |h,k|
            if reason = invalid_object_type(k)
              raise InvalidObjectType.new(@vocabulary, k, reason)
            end
            h[k] = InstanceIndex.new(self, k, (@options.include?(:sort) ? @options[:sort] : API::sorted))
          end
      end

      # Candidates is an array of object instances that do not already exist
      # in the constellation but will be added if an assertion succeeds.
      # After the assertion is found to be acceptable, these objects are indexed
      # in the constellation and in the counterparts of their identifying roles,
      # and the candidates array is nullified.
      def with_candidates &b
        # Multiple assignment reduces (s)teps while debugging
        outermost, @candidates, @on_admission = @candidates.nil?, (@candidates || []), (@on_admission || [])
        begin
          b.call
        rescue Exception
          # Do not accept any of these candidates, there was a problem:
          @candidates = [] if outermost
          raise
        ensure
          if outermost
            while @candidates
              # Index the accepted instances in the constellation:
              candidates = @candidates
              on_admission = @on_admission
              @candidates = nil
              @on_admission = nil
              candidates.each do |instance|
                instance.class.index_instance(self, instance)
                loggers.each{|l| l.call(:assert, instance.class, instance.identifying_role_values)}
              end
              on_admission.each do |b|
                b.call
              end
            end
          end
        end
      end

      def when_admitted &b
        if @candidates.nil?
          b.call self
        else
          @on_admission << b
        end
      end

      def candidate instance
        @candidates << instance unless @candidates[-1] == instance
      end

      def has_candidate klass, key
        @candidates && @candidates.detect{|c| c.is_a?(klass) && c.identifying_role_values(klass) == key }
      end

      # This method removes the given instance from this constellation's indexes
      # It must be called before the identifying roles get deleted or nullified.
      def deindex_instance(instance) #:nodoc:
        last_irns = nil
        last_irvs = instance
        ([instance.class]+instance.class.supertypes_transitive).each do |klass|
          if instance.is_a?(Entity) and last_irns != (n = klass.identifying_role_names)
            # Build new identifying_role_values only when the identifying_role_names change:
            last_irvs = instance.identifying_role_values(klass)
            last_irns = n
          end
          deleted = instances[klass].delete(last_irvs)
          # The RBTree class sometimes returns a different object than what was deleted! Check non-nil:
          raise "Internal error: deindex #{instance.class} as #{klass} failed" if deleted == nil
        end
      end

      # Constellations verbalise all members of all classes in alphabetical order, showing
      # non-identifying role values as well
      def verbalise
        "Constellation over #{vocabulary.name}:\n" +
        vocabulary.object_type.keys.sort.map do |object_type|
            klass = vocabulary.const_get(object_type)

            single_roles, multiple_roles = klass.all_role.
                partition do |n, r|
                  r.unique &&               # Show only single-valued roles
                    !r.is_identifying &&    # Unless identifying
                    (r.unary? || !r.counterpart.is_identifying) # Or identifies a counterpart
                end.
                map do |rs|
                  rs.map{|n, r| n}.
                    sort_by(&:to_s)
                end

            instances = send(object_type.to_sym)
            next nil unless instances.size > 0
            "\tEvery #{object_type}:\n" +
              instances.map do |key, instance|
                  s = "\t\t" + instance.verbalise
                  if (single_roles.size > 0)
                    role_values = 
                      single_roles.map do |role_name|
                          #p klass, klass.all_role.keys; exit
                          next nil if klass.all_role(role_name).fact_type.is_a?(TypeInheritanceFactType)
                          value =
                            if instance.respond_to?(role_name)
                              value = instance.send(role_name)
                            else
                              instance.class.all_role(role_name) # This role has not yet been realised
                            end
                          [ role_name.to_s.camelcase, value ]
                        end.compact.select do |role_name, value|
                          value
                        end.map do |role_name, value|
                          "#{role_name} = #{value ? value.verbalise : "nil"}"
                        end
                    s += " where " + role_values*", " if role_values.size > 0
                  end
                  s
                end * "\n"
          end.compact*"\n"
      end

      # Make a new instance like "instance", but with some new attributes assigned.
      # All identifiers should overall be different from the forked instance, and
      # all one-to-ones must be assigned new values (otherwise we change old objects)
      def fork instance, attrs = {}
        object_type = instance.class

        role_value_map =
          object_type.all_role_transitive.inject({}) do |hash, (role_name, role)|
            next hash if !role.unique
            next hash if role.fact_type.class == ActiveFacts::API::TypeInheritanceFactType
            old_value = instance.send(role.getter)
            if role.counterpart && role.counterpart.unique && old_value != nil
              # It's a one-to-one which is populated. We must not change the counterpart
              if role.mandatory && !attrs.include?(role.name)
                # and cannot just nullify the value
                raise "#{object_type.basename} cannot be forked unless a replacement value for #{role.name} is provided"
              end
              value = attrs[role_name]
            else
              value = attrs.include?(role_name) ? attrs[role_name] : instance.send(role.getter)
            end
            hash[role_name] = value if value != nil
            hash
          end

          assert(object_type, role_value_map)
      end

      def clone
        remaining_object_types = vocabulary.object_type.clone
        constellation = self.class.new(vocabulary, @options)
        correlates = {}
        other_attribute_assignments = []
        until remaining_object_types.empty?
          count = 0
          # Choose an object type we can clone now:
          name, object_type = *remaining_object_types.detect do |name, o|
            (count = @instances[o].size) == 0 or        # There are no instances of this object type; clone is ok
              !o.is_entity_type or                      # It's a value type
              (
                !o.subtypes_transitive.detect do |subtype|# All its subtypes have been cloned
                    remaining_object_types.has_key?(subtype.basename)
                end and
                !o.identifying_roles.detect do |role|   # The players of its identifying roles have all been dumped
                  next unless role.counterpart              # Unary role, no player
                  counterpart = role.counterpart.object_type  # counterpart object

                  # The identifying type and its subtypes have been dumped
                  ([counterpart]+counterpart.subtypes_transitive).detect do |subtype|
                    remaining_object_types.has_key?(subtype.basename)
                  end
                end
              )
          end
#         puts "Cloning #{count} instances of #{name}" if count > 0
          remaining_object_types.delete(name)

          key_role_names =
            if object_type.is_entity_type
              ([object_type]+object_type.supertypes_transitive).map { |t| t.identifying_role_names }.flatten.uniq
            else
              nil
            end
          other_roles = object_type.all_role_transitive.map do |role_name, role|
              next if !role.unique or
                role.fact_type.class == ActiveFacts::API::TypeInheritanceFactType or
                role.fact_type.all_role[0] != role or  # Only the first role in a one-to-one pair
                key_role_names.include?(role_name)
              role
            end.compact - Array(key_role_names)

          @instances[object_type].each do |key, object|
            next if object.class != object_type

            # Clone this object

            # Get the identifying values:
            key = object
            if (key_role_names)
              key = key_role_names.inject({}) do |h, krn|
                  h[krn] = object.send(krn)
                  h
                end
            end
#           puts "\tcloning #{object.class} #{key.inspect}"
#           puts "\t\talso copy #{other_roles.map(&:name)*', '}"

            new_object = constellation.assert(object_type, key)
            correlates[object] = new_object

            other_roles.each do |role|
              value = object.send(role.getter)
              next unless value
              other_attribute_assignments << proc do
                new_object.send(role.setter, correlates[value])
              end
            end
          end
        end

        # Now, assign all non-identifying facts
#       puts "Assigning #{other_attribute_assignments.size} additional roles"
        other_attribute_assignments.each do |assignment|
          assignment.call
        end

        constellation
      end

    end

    def self.sorted
      # Sorting defaults to true, unless you set ACTIVEFACTS_SORT to "[n]o" or [f]false"
      @@af_sort_name ||= "ACTIVEFACTS_SORT"
      sort = ENV[@@af_sort_name]
      !sort or !%w{n f}.include?(sort[0])
    end

  end
end
