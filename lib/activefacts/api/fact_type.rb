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

      def initialize
	@all_role = []
      end
    end
  end
end
