#
#       ActiveFacts API
#       Role class.
#       Each accessor method created on an instance corresponds to a Role object in the instance's class.
#       Binary fact types construct a Role at each end.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API

    # A Role represents the relationship of one object to another (or to a boolean condition).
    # Relationships (or binary fact types) have a Role at each end; one is declared using _has_one_
    # or _one_to_one_, and the other is created on the counterpart class.
    # Each ObjectType class maintains a RoleCollection hash of the roles it plays.
    class Role
      attr_reader   :object_type      # The ObjectType to which this role belongs
      attr_reader   :is_unary
      attr_reader   :name             # The name of the role (a Symbol)
      attr_accessor :counterpart      # All roles except unaries have a counterpart Role
      attr_reader   :unique           # Is this role played by at most one instance, or more?
      attr_reader   :mandatory        # In a valid fact population, is this role required to be played?
      attr_reader   :value_constraint # Counterpart Instances playing this role must meet this constraint
      attr_reader   :is_identifying   # Is this an identifying role for object_type?

      def initialize(object_type, counterpart, name, mandatory = false, unique = true)
        @object_type = object_type
        @is_unary = counterpart == TrueClass
        @counterpart = @is_unary ? nil : counterpart
        @name = name
        @mandatory = mandatory
        @unique = unique
        @is_identifying = @object_type.is_entity_type && @object_type.identifying_role_names.include?(@name)
        associate_role(@object_type)
      end

      # Return the name of the getter method
      def getter
        @getter ||= @name.to_sym
      end

      # Return the name of the setter method
      def setter
        @setter ||= :"#{@name}="
      end

      # Return the name of the instance variable
      def variable
        @variable ||= "@#{@name}"
      end

      # Is this role a unary (created by maybe)? If so, it has no counterpart
      def unary?
        # N.B. A role with a forward reference looks unary until it is resolved.
        counterpart == nil
      end

      def is_inherited?(klass)
        klass.supertypes_transitive.include?(@object_type)
      end

      def counterpart_object_type
        # This method is sometimes used when unaries are used in an entity's identifier.
        @is_unary ? TrueClass : (counterpart ? counterpart.object_type : nil)
      end

      def inspect
        "<Role #{object_type.name}.#{name}>"
      end

      def adapt(constellation, value) #:nodoc:
        # If the value is a compatible class, use it (if in another constellation, clone it),
        # else create a compatible object using the value as constructor parameters.
        if value.is_a?(counterpart.object_type)
          # Check that the value is in a compatible constellation, clone if not:
          if constellation && (vc = value.constellation) && vc != constellation
            value = constellation.copy(value)
          end
          value.constellation = constellation if constellation
        else
          value = [value] unless Array === value
          raise "No parameters were provided to identify an #{counterpart.object_type.basename} instance" if value == []
          if constellation
            value = constellation.send(counterpart.object_type.basename.to_sym, *value)
          else
            #trace :assert, "Constructing new #{counterpart.object_type} with #{value.inspect}" do
              value = counterpart.object_type.new(*value)
            #end
          end
        end
        value
      end

    private
      # Create a class method to access the Role object.
      # This seems to add *significantly* to the runtime of the tests,
      # but it's load-time, not execution-time, so it's staying!
      def associate_role(klass)
        role = self
        klass.class_eval do
          role_accessor_name = "#{role.name}_role"
          unless (method(role_accessor_name) rescue nil)
            (class << self; self; end).
              send(:define_method, role_accessor_name) do
                role
              end
          # else we can't create such a method without creating mayhem, so don't.
          end
        end
      end
    end

    # Every ObjectType has a Role collection
    # REVISIT: You can enumerate the object_type's own roles, or inherited roles as well.
    class RoleCollection < Hash #:nodoc:
      def verbalise
        keys.sort_by(&:to_s).inspect
      end
    end
  end
end
