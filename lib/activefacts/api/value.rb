#
#       ActiveFacts Runtime API
#       Value module (mixins for ValueType classes and instances)
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
# The methods of this module are added to Value type classes.
#

module ActiveFacts
  module API

    # All Value instances include the methods defined here
    module Value
      include Instance

      # Value instance methods:
      def initialize(*args) #:nodoc:
        arg_hash = args[-1].is_a?(Hash) ? args.pop.clone : nil

        super(args)
      end

      # verbalise this Value
      def verbalise(role_name = nil)
        "#{role_name || self.class.basename} '#{to_s}'"
      end

      # A value is its own key, unless it's a delegate for a raw value
      def identifying_role_values(klass = nil) #:nodoc:
	# The identifying role value for the supertype of a value type is always the same as for the subtype
	respond_to?(:__getobj__) ? __getobj__ : self
      end

      def plays_no_role
	# REVISIT: Some Value Types are independent, and so must always be regarded as playing a role
	self.class.all_role.all? do |n, role|
	  case
	  when role.fact_type.is_a?(ActiveFacts::API::TypeInheritanceFactType)
	    true  # No need to consider subtyping/supertyping roles here
	  when role.unique
	    send(role.getter) == nil
	  else
	    send(role.getter).empty?
	  end
	end
      end

      # All ValueType classes include the methods defined here
      module ClassMethods
        include Instance::ClassMethods

        def value_type *args, &block #:nodoc:
          options = (args[-1].is_a?(Hash) ? args.pop : {})
          options.each do |key, value|
	    raise UnrecognisedOptionsException.new('ValueType', basename, key) unless respond_to?(key)
            send(key, value)
          end
        end

        class_eval do
          define_method :length do |*args|
            @length = args[0] if args.length > 0
            @length
          end
        end

        class_eval do
          define_method :scale do |*args|
            @scale = args[0] if args.length > 0
            @scale
          end
        end

        class_eval do
          define_method :restrict do |*value_ranges|
            @value_ranges = *value_ranges
          end
        end

        # verbalise this ValueType
        def verbalise
          "#{basename} < #{superclass.basename}();"
        end

        def identifying_role_values(constellation, args)   #:nodoc:
	  # Normalise positional arguments into an arguments hash (this changes the passed parameter)
	  arg_hash = args[-1].is_a?(Hash) ? args.pop : {}

          # If a single arg is already the correct class or a subclass,
	  # use it directly, otherwise create one.
	  # This appears to be the only way to handle e.g. Date correctly
          unless args.size == 1 and instance = args[0] and instance.is_a?(self)
	    instance = new_instance(constellation, *args)
          end
	  args.replace([arg_hash])
	  instance.identifying_role_values(self)
        end

	def assert_instance(constellation, args)
	  new_identifier = args == [:new]
	  key = identifying_role_values(constellation, args)
	  # args are now normalized to an array containing a single Hash element
	  arg_hash = args[0]

	  if new_identifier
	    instance = key  # AutoCounter is its own key
	  else
	    instance_index = constellation.instances[self]
	    unless instance = constellation.has_candidate(self, key) || instance_index[key]
	      instance = new_instance(constellation, key)
	      constellation.candidate(instance)
	    end
	  end

	  # Assign any extra roles that may have been passed.
	  # An exception here leaves the object as a candidate,
	  # but without the offending role (re-)assigned.
	  arg_hash.each do |k, v|
	    instance.send(:"#{k}=", v)
	  end

	  instance
	end

        def index_instance(constellation, instance) #:nodoc:
	  # Index the instance in the constellation's InstanceIndex for this class:
          instances = constellation.instances[self]
          key = instance.identifying_role_values(self)
          instances[key] = instance

          # Index the instance for each supertype:
          supertypes.each do |supertype|
            supertype.index_instance(constellation, instance)
          end

          instance
        end

        def inherited(other)  #:nodoc:
          # Copy the type parameters here, etc?
          other.send :realise_supertypes, self
	  TypeInheritanceFactType.new(self, other)
          vocabulary.__add_object_type(other)
          super
        end
      end

      def self.included klass #:nodoc:
        klass.send :extend, ClassMethods

        if !klass.respond_to?(:new_instance)
          class << klass
            def new_instance constellation, *args
              instance = allocate
              instance.instance_variable_set(@@constellation_variable_name ||= "@constellation", constellation)
              instance.send(:initialize, *args)
              instance
            end
          end
        end

        # Register ourselves with the parent module, which has become a Vocabulary:
        vocabulary = klass.modspace
        unless vocabulary.respond_to? :object_type  # Extend module with Vocabulary if necessary
          vocabulary.send :extend, Vocabulary
        end
        vocabulary.__add_object_type(klass)
      end
    end
  end
end
