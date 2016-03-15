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
    class FactType
      attr_accessor :all_role
      # invariant { self.all_role.each {|role| self.is_a?(ObjectifiedFactType) ? role.counterpart.object_type == self.objectified_as : role.fact_type == self } }

      def initialize
        @all_role ||= []
      end
    end

    class ObjectifiedFactType < FactType
      # The roles of an ObjectifiedFactType are roles in the link fact types.
      # This means that all_role[*].fact_type does not point to this fact type,
      # as would normally be the case.
      # invariant { self.all_role.each {|role| role.counterpart.object_type == self.objectified_as } }
      attr_reader :objectified_as
      # invariant { self.objectified_as.objectification_of == self }
    end

    class TypeInheritanceFactType < FactType
      attr_reader :supertype_role, :subtype_role
    
      def initialize(supertype, subtype)
        super()

        # The supertype role is not mandatory, but the subtype role is. Both are unique.
        @supertype_role = Role.new(self, supertype, subtype.name.gsub(/.*::/,'').to_sym, false, true)
        @subtype_role = Role.new(self, subtype, supertype.name.gsub(/.*::/,'').to_sym, true, true)
      end
    end
  end
end
