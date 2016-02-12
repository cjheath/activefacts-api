#
#       ActiveFacts Runtime API
#       Vocabulary module (mixin for any Module that contains classes having ObjectType mixed in)
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
# The methods of this module are extended into any module that contains
# a ObjectType class (Entity type or Value type).
#
module ActiveFacts
  module API
    # Vocabulary is a mixin that adds methods to any Module which has any ObjectType classes (ValueType or EntityType).
    # A Vocabulary knows all the ObjectType classes including forward-referenced ones,
    # and can resolve the forward references when the class is finally defined.
    # Construction of a Constellation requires a Vocabulary as argument.
    module Vocabulary
      # With a parameter, look up an object type by name.
      # Without, return the hash (keyed by the class' basename) of all object_types in this vocabulary
      def object_type(name = nil)
        @object_type ||= {}
        return @object_type unless name

        if name.is_a? Class
          unless name.respond_to?(:vocabulary) and name.vocabulary == self
            raise CrossVocabularyRoleException.new(name, self)
          end
          return name
        end

        camel = name.to_s.camelcase
        if (c = @object_type[camel])
          __bind(camel)
          c
        else
	  klass = const_get(camel) rescue nil	# NameError if undefined
	  klass && klass.modspace == self ? klass : nil
        end
      end

      # Create a new constellation over this vocabulary
      def constellation
        Constellation.new(self)
      end

      def populate &b
        constellation.populate &b
      end

      def verbalise
        "Vocabulary #{name}:\n\t" +
          @object_type.keys.sort.map do |object_type|
	    c = @object_type[object_type]
	    __bind(c.basename)
	    c.verbalise + "\n\t\t// Roles played: " + c.all_role.verbalise
	  end.
	  join("\n\t")
      end

      def __add_object_type(klass)  #:nodoc:
        name = klass.basename
        __bind(name)
        @object_type ||= {}
        @object_type[klass.basename] = klass
      end

      def __delay(object_type_name, args, &block) #:nodoc:
        delayed[object_type_name] << [args, block]
      end

      # __bind raises an error if the named class doesn't exist yet.
      def __bind(object_type_name)  #:nodoc:
        object_type = const_get(object_type_name)
        if (delayed.include?(object_type_name))
          d = delayed[object_type_name]
          d.each{|(a,b)|
              b.call(object_type, *a)
            }
          delayed.delete(object_type_name)
        end
      end

      def delayed
        @delayed ||= Hash.new { |h,k| h[k] = [] }
        @delayed
      end

    end
  end
end
