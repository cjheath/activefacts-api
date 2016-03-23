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
      attr_reader   :fact_type        # The FactType to which this role belongs
      attr_reader   :object_type      # The ObjectType to which this role belongs
      attr_reader   :name             # The name of the role (a Symbol)
      attr_reader   :unique           # Is this role played by at most one instance, or more?
      attr_reader   :mandatory        # In a valid fact population, is this role required to be played?
      attr_reader   :value_constraint # Counterpart Instances playing this role must meet this constraint

      def is_identifying # Is this an identifying role for object_type?
        return @is_identifying unless @is_identifying == nil
        @is_identifying = !!(@object_type.is_entity_type && @object_type.identifying_role_names.include?(@name))
      end

      def initialize(fact_type, object_type, role_name, mandatory, unique, restrict = nil)
        @fact_type = fact_type
        @fact_type.all_role << self
        @object_type = object_type
        @name = role_name
        @mandatory = mandatory
        @unique = unique
        @value_constraint = restrict
        object_type.add_role(self)
        associate_role(@object_type)
      end

      # Is this role a unary (created by maybe)?
      def unary?
        # N.B. A role with a forward reference looks unary until it is resolved.
        @fact_type.all_role.size == 1
      end

      def make_mandatory
        # Sometimes a role has already been defined from the other end
        @mandatory = true
      end

      def counterpart
        @counterpart ||= (@fact_type.all_role - [self])[0]
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

      def inspect
        "<Role #{object_type.name}.#{name}>"
      end

      def verbalise
        "Role #{name} of #{object_type}, " +
          (unary? ? 'unary' : (counterpart ? 'played by' + counterpart.object_type : 'undefined'))
      end

    private
      # Create a class method to access the Role object.
      # This seems to add *significantly* to the runtime of the tests (method cache flushing?),
      # but it's load-time, not execution-time, so it's staying!
      def associate_role(klass)
        role = self
        klass.class_eval do
          role_accessor_name = "#{role.name}_role"
          unless respond_to?(role_accessor_name)
            singleton_class.send(:define_method, role_accessor_name) do
              role
            end
          # else we can't create such a method without creating mayhem, so don't.
          end
        end
      end
    end

    # Every ObjectType has a Role collection
    class RoleCollection < Hash #:nodoc:
      def verbalise
        keys.sort_by(&:to_s).inspect
      end
    end
  end
end
