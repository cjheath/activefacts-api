#
#       ActiveFacts Runtime API
#       ObjectType (a mixin module for the class Class)
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#

module ActiveFacts
  module API
    module Vocabulary; end

    # ObjectType contains methods that are added as class methods to all Value and Entity classes.
    module ObjectType
      SKIP_MUTUAL_PROPAGATION = 0x1
      CHECKED_IDENTIFYING_ROLE = 0x2

      # What vocabulary (Ruby module) does this object_type belong to?
      def vocabulary
        modspace        # The module that contains this object_type.
      end

      # Each ObjectType maintains a list of the Roles it plays:
      def all_role(role_name = nil)
        unless instance_variable_defined?(@@all_role_name ||= "@all_role")  # Avoid "instance variable not defined" warning from ||=
          @all_role = RoleCollection.new
        end
        case role_name
        when nil
          @all_role
        when Symbol, String
          # Search this class then all supertypes:
          unless role = @all_role[role_name.to_sym]
            role = nil
            supertypes.each do |supertype|
                begin
                  role = supertype.all_role(role_name)
                rescue RoleNotDefinedException
                  next
                end
                break
              end
          end
          unless role
            raise RoleNotDefinedException.new(self, role_name)
          end
          role
        else
          nil
        end
      end

      def add_role(role)
	all_role[role.name] = role
	@all_role_transitive = nil  # Undo the caching
      end

      def all_role_transitive
	return @all_role_transitive if @all_role_transitive
	@all_role_transitive = all_role.dup
	supertypes_transitive.each do |klass|
	  @all_role_transitive.merge!(klass.all_role)
	end
	@all_role_transitive
      end

      # Define a unary fact type attached to this object_type; in essence, a boolean attribute.
      #
      # Example: maybe :is_ceo
      def maybe(role_name, options = {})
	raise UnrecognisedOptionsException.new("role", role_name, options.keys) unless options.empty?
	fact_type = FactType.new
        realise_role(Role.new(fact_type, self, role_name, false, true))
      end

      # Define a binary fact type relating this object_type to another,
      # with a uniqueness constraint only on this object_type's role.
      # This method creates two accessor methods, one in this object_type and one in the other object_type.
      # * role_name is a Symbol for the name of the role (this end of the relationship)
      # Options contain optional keys:
      # * :class - A class name, Symbol or String naming a class, required if it doesn't match the role_name. Use a symbol or string if the class isn't defined yet, and the methods will be created later, when the class is first defined.
      # * :mandatory - if this role may not be NULL in a valid fact population, say :mandatory => true. Mandatory constraints are only enforced during validation (e.g. before saving).
      # * :counterpart - use if the role at the other end should have a name other than the default :all_<object_type> or :all_<object_type>\_as_<role_name>
      # * :reading - for verbalisation. Not used yet.
      # * :restrict - a list of values or ranges which this role may take. Not used yet.
      def has_one(role_name, options = {})
        role_name, related, mandatory, related_role_name = extract_binary_params(false, role_name, options)
        check_identifying_role_has_valid_cardinality(:has_one, role_name)
        define_binary_fact_type(false, role_name, related, mandatory, related_role_name)
      end

      # Define a binary fact type joining this object_type to another,
      # with uniqueness constraints in both directions, i.e. a one-to-one relationship
      # This method creates two accessor methods, one in this object_type and one in the other object_type.
      # * role_name is a Symbol for the name of the role (this end of the relationship)
      # Options contain optional keys:
      # * :class - A class name, Symbol or String naming a class, required if it doesn't match the role_name. Use a symbol or string if the class isn't defined yet, and the methods will be created later, when the class is first defined.
      # * :mandatory - if this role may not be NULL in a valid fact population, say :mandatory => true. Mandatory constraints are only enforced during validation (e.g. before saving).
      # * :counterpart - use if the role at the other end should have a name other than the default :all_<object_type> or :all_<object_type>\_as_<role_name>
      # * :reading - for verbalisation. Not used yet.
      # * :restrict - a list of values or ranges which this role may take. Not used yet.
      def one_to_one(role_name, options = {})
        role_name, related, mandatory, related_role_name =
          extract_binary_params(true, role_name, options)
        check_identifying_role_has_valid_cardinality(:one_to_one, role_name)
        define_binary_fact_type(true, role_name, related, mandatory, related_role_name)
      end

      def check_identifying_role_has_valid_cardinality(type, role)
        if is_entity_type && identifying_role_names.include?(role)
          case type
          when :has_one
            if identifying_role_names.size == 1
	      raise InvalidIdentificationException.new(self, role, true)
            end
          when :one_to_one
            if identifying_role_names.size > 1
	      raise InvalidIdentificationException.new(self, role, false)
            end
          end
        end
      end

      # Access supertypes or add new supertypes; multiple inheritance.
      # With parameters (Class objects), it adds new supertypes to this class.
      # Instances of this class will then have role methods for any new superclasses (transitively).
      # Superclasses must be Ruby classes which are existing ObjectTypes.
      # Without parameters, it returns the array of ObjectType supertypes
      # (one by Ruby inheritance, any others as defined using this method)
      def supertypes(*object_types)
	@supertypes ||= []
	all_supertypes = supertypes_transitive
	object_types.each do |object_type|
	  next if all_supertypes.include? object_type
	  supertype =
	    case object_type
	    when Class
	      object_type
	    when Symbol
	      # No late binding here:
	      (object_type = vocabulary.const_get(object_type.to_s.camelcase))
	    else
	      raise InvalidSupertypeException.new("Illegal supertype #{object_type.inspect} for #{self.class.basename}")
	    end
	  unless supertype.respond_to?(:vocabulary) and supertype.vocabulary == self.vocabulary
	    raise InvalidSupertypeException.new("#{supertype.name} must be an object type in #{vocabulary.name}")
	  end

	  if is_entity_type != supertype.is_entity_type
	    raise InvalidSupertypeException.new("#{self} < #{supertype}: A value type may not be a supertype of an entity type, and vice versa")
	  end

	  TypeInheritanceFactType.new(supertype, self)
	  @supertypes << supertype

	  # Realise the roles (create accessors) of this supertype.
	  realise_supertypes(object_type, all_supertypes)
	end
	[(superclass.respond_to?(:vocabulary) ? superclass : nil), *@supertypes].compact
      end

      # Return the array of all ObjectType supertypes, transitively.
      def supertypes_transitive
	supertypes = []
	v = superclass.respond_to?(:vocabulary) ? superclass.vocabulary : nil
	supertypes << superclass if v.kind_of?(Module)
	supertypes += (@supertypes ||= [])
	sts = supertypes.inject([]) do |a, t|
	  next if a.include?(t)
	  a += [t] + t.supertypes_transitive
	end.uniq
	sts # The local variable unconfuses rcov
      end

      def subtypes
        @subtypes ||= []
      end

      def subtypes_transitive
	(subtypes+subtypes.map(&:subtypes_transitive)).flatten.uniq
      end

      # Every new role added or inherited comes through here:
      def realise_role(role) #:nodoc:
        if (role.unary?)
          # Unary role
          define_unary_role_accessor(role)
        elsif (role.unique)
          if role.counterpart.unique
            define_one_to_one_accessor(role)
          else
            define_one_to_many_accessor(role)
          end
        else
          define_many_to_one_accessor(role)
        end
      end

      private

      def realise_supertypes(object_type, all_supertypes = nil)
        all_supertypes ||= supertypes_transitive
        s = object_type.supertypes
        s.each do |t|
          next if all_supertypes.include? t
          realise_supertypes(t, all_supertypes)
          t.subtypes << self unless t.subtypes.include?(self)
          all_supertypes << t
        end
        realise_roles(object_type)
      end

      # Realise all the roles of a object_type on this object_type, used when a supertype is added:
      def realise_roles(object_type)
        object_type.all_role.each do |role_name, role|
          realise_role(role)
        end
      end

      # Shared code for both kinds of binary fact type (has_one and one_to_one)
      def define_binary_fact_type(one_to_one, role_name, related, mandatory, related_role_name)
	if all_role_transitive[role_name]
	  raise DuplicateRoleException.new("#{name} cannot have more than one role named #{role_name}")
	end
	fact_type = FactType.new
        role = Role.new(fact_type, self, role_name, mandatory, true)

        # There may be a forward reference here where role_name is a Symbol,
        # and the block runs later when that Symbol is bound to the object_type.
        when_bound(related, self, role_name, related_role_name) do |target, definer, role_name, related_role_name|
	  counterpart = Role.new(fact_type, target, related_role_name, false, one_to_one)
          realise_role(role)
          target.realise_role(counterpart)
        end
      end

      def define_unary_role_accessor(role)
	define_method role.setter do |value, options = 0|
	  # Normalise the value to be assigned (nil, false, true):
	  value = case value
	    when nil; nil
	    when false; false
	    else true
	    end

	  old = instance_variable_get(role.variable)
	  return value if old == value

	  if role.is_identifying and (options&CHECKED_IDENTIFYING_ROLE) == 0
	    check_identification_change_legality(role, value)
	    impacts = analyse_impacts(role)
	  end

	  instance_variable_set(role.variable, value)

	  if impacts
	    @constellation.when_admitted do
	      # REVISIT: Consider whether we want to provide a way to find all instances
	      # playing/not playing this boolean role, analogous to true.all_thing_as_role_name...
	      apply_impacts(impacts)	# Propagate dependent key changes
	    end
	  end

	  unless @constellation.loggers.empty? or options != 0
	    sv = self.identifying_role_values(role.object_type)
	    @constellation.loggers.each{|l| l.call(:assign, role.object_type, role, sv, old, value) }
	  end

	  value
	end
        define_single_role_getter(role)
      end

      def define_single_role_getter(role)
	define_method role.getter do |*a|
	  if a.size > 0
	    raise ArgumentError.new("wrong number of arguments (#{a.size} for 0)")
	  end
	  instance_variable_get(role.variable)
	end
      end

      def define_one_to_one_accessor(role)
        define_single_role_getter(role)

	# What I want is the following, but it doesn't work in Ruby 1.8
	define_method role.setter do |value, options = 0|
	  role_var = role.variable

	  # Get old value, and jump out early if it's unchanged:
	  old = instance_variable_get(role_var)
	  return value if old == value

	  # assert a new instance for the role value if necessary
	  if value and o = role.counterpart.object_type and (!value.is_a?(o) || value.constellation != @constellation)
	    value = @constellation.assert(o, *Array(value))
	    return value if old == value
	  end

	  # We're changing this object's key. Check legality and prepare to propagate
	  if role.is_identifying and (options&CHECKED_IDENTIFYING_ROLE) == 0
	    check_identification_change_legality(role, value)

	    # puts "Starting to analyse impact of changing 1-1 #{role.inspect} to #{value.inspect}"
	    impacts = analyse_impacts(role)
	  end

	  instance_variable_set(role_var, value)

	  # Remove self from the old counterpart:
	  if old and (options&SKIP_MUTUAL_PROPAGATION) == 0
	    old.send(role.counterpart.setter, nil, options|SKIP_MUTUAL_PROPAGATION)
	  end

	  @constellation.when_admitted do
	    # Assign self to the new counterpart
	    value.send(role.counterpart.setter, self, options) if value && (options&SKIP_MUTUAL_PROPAGATION) == 0

	    apply_impacts(impacts) if impacts	# Propagate dependent key changes
	  end

	  unless @constellation.loggers.empty? or options != 0
	    sv = self.identifying_role_values(role.object_type)
	    ov = old.identifying_role_values
	    nv = value.identifying_role_values
	    @constellation.loggers.each{|l| l.call(:assign, role.object_type, role, sv, ov, nv) }
	  end

	  value
	end
      end

      def define_one_to_many_accessor(role)
        define_single_role_getter(role)

	define_method role.setter do |value, options = 0|
	  role_var = role.variable

	  # Get old value, and jump out early if it's unchanged:
	  old = instance_variable_get(role_var)
	  return value if old == value

	  # assert a new instance for the role value if necessary
	  if value and o = role.counterpart.object_type and (!value.is_a?(o) || value.constellation != @constellation)
	    value = @constellation.assert(o, *Array(value))
	    return value if old == value	# Occurs when another instance having the same value is assigned
	  end

	  if role.is_identifying and (options&CHECKED_IDENTIFYING_ROLE) == 0
	    # We're changing this object's key. Check legality and prepare to propagate
	    check_identification_change_legality(role, value)

	    # puts "Starting to analyse impact of changing 1-N #{role.inspect} to #{value.inspect}"
	    impacts = analyse_impacts(role)
	  end

	  if old and (options&SKIP_MUTUAL_PROPAGATION) == 0
	    old_role_values = old.send(getter = role.counterpart.getter)
	    old_key = old_role_values.index_values(self)
	  end

	  instance_variable_set(role_var, value)

	  # Remove "self" from the old counterpart:
	  if old_key
	    old_role_values.delete_instance(self, old_key)
	    if (old_role_values.empty? && !old.class.is_entity_type)
	      old.retract if old.plays_no_role
	    end
	  end

	  @constellation.when_admitted do
	    # Add "self" into the counterpart
	    value.send(getter ||= role.counterpart.getter).add_instance(self, identifying_role_values(role.object_type)) if value

	    apply_impacts(impacts) if impacts	# Propagate dependent key changes
	  end

	  unless @constellation.loggers.empty? or options != 0
	    sv = self.identifying_role_values(role.object_type)
	    ov = old.identifying_role_values
	    nv = value.identifying_role_values
	    @constellation.loggers.each{|l| l.call(:assign, role.object_type, role, sv, ov, nv) }
	  end

	  value
	end
      end

      def define_many_to_one_accessor(role)

	define_method role.getter do |*keys|
	  role_var = role.variable
	  role_values =
	    instance_variable_get(role_var) || begin

	      # Decide which roles this index will use (exclude the counterpart role from the id)
	      if role.counterpart and
		  counterpart = role.counterpart.object_type and
		  counterpart.is_entity_type
		index_roles = counterpart.identifying_roles - [role.counterpart]
	      else
		index_roles = nil
	      end

	      instance_variable_set(role_var, RoleValues.new(role.counterpart.object_type, index_roles))
	    end
	  # Look up a value by the key provided, or return the whole collection
	  keys.size == 0 ? role_values : role_values.[](*keys)
        end
      end

      # Extract the parameters to a role definition and massage them into the right shape.
      #
      # The first parameter, role_name, is mandatory. It may be a Symbol, a String or a Class.
      # New proposed input options:
      # :class => the related class (Class object or Symbol). Not allowed if role_name was a class.
      # :mandatory => true. There must be a related object for this object to be valid.
      # :counterpart => Symbol/String. The name of the counterpart role. Will be to_s.snakecase'd and maybe augmented with "all_" and/or "_as_<role_name>"
      # LATER:
      # :order => :local_role OR lambda{} (for sort_by)
      # :restrict => Range or Array of Range/value or respond_to?(include?)
      #
      # This function returns an array:
      # [ role_name,
      # related,
      # mandatory,
      # related_role_name ]
      #
      # Role naming rule:
      #   "all_" if there may be more than one (only ever on related end)
      #   Role Name:
      # If a role name is defined at this end:
      #   Role Name
      # else:
      #   Leading Adjective
      #   Role counterpart object_type name (not role name)
      #   Trailing Adjective
      # "_as_<other_role_name>" if other_role_name != this role's counterpart' object_type name, and not other_player_this_player
      def extract_binary_params(one_to_one, role_name, options)
        # Options:
        #   mandatory (:mandatory)
        #   other end role name if any (Symbol),
        related = nil
        mandatory = false
        related_role_name = nil
        role_player = self.basename.snakecase

        role_name = (Class === role_name ? a.name.snakecase : role_name).to_sym

        # The related class might be forward-referenced, so handle a Symbol/String instead of a Class.
        specified_class = related_name = options.delete(:class)
        case related_name
        when nil
          related = role_name # No :class provided, assume it matches the role_name
          related_name ||= role_name.to_s
        when Class
          related = related_name
          related_name = related_name.basename.to_s.snakecase
        when Symbol, String
          related = related_name
          related_name = related_name.to_s.snakecase
        else
          raise ArgumentError.new("Invalid type #{related_name.class} for :class option on :#{role_name}, must be a Class, Symbol or String")
        end

        # resolve the Symbol to a Class now if possible:
        resolved = vocabulary.object_type(related)
        related = resolved if resolved
        if related.is_a?(Class)
          unless related.respond_to?(:vocabulary) and related.vocabulary == self.vocabulary
            raise CrossVocabularyRoleException.new(related, vocabulary)
          end
        end

        if options.delete(:mandatory) == true
          mandatory = true
        end

        related_role_name = related_role_name.to_s if related_role_name = options.delete(:counterpart)

	raise UnrecognisedOptionsException.new("role", role_name, options.keys) unless options.empty?

        # If you have a role "supervisor" and a sub-class "Supervisor", this'll bitch.
        if !specified_class and		# No specified :class was provided
	    related.is_a?(Class) and
	    (indicated = vocabulary.object_type(role_name)) and
	    indicated != related
          raise "Role name #{role_name} indicates a different counterpart object_type #{indicated} than specified"
        end

        # This code probably isn't as quick or simple as it could be, but it does work right,
        # and that was pretty hard, because the variable naming is all over the shop. Should fix
        # the naming first (here and in generate/oo.rb) then figure out how to speed it up.
        # Note that oo.rb names things from the opposite end, so you wind up in a maze of mirrors.
        other_role_method =
          (one_to_one ? "" : "all_") +
          (related_role_name || role_player)
        if role_name.to_s != related_name and
            (!related_role_name || related_role_name == role_player)
          other_role_method += "_as_#{role_name}"
        end

        [ role_name,
          related,
          mandatory,
          other_role_method.to_sym 
        ]
      end

      def when_bound(object_type, *args, &block)
        case object_type
        when Class
          block.call(object_type, *args)    # Execute block in the context of the object_type
        when Symbol
          vocabulary.__delay(object_type.to_s.camelcase, args, &block)
        when String     # Arrange for this to happen later
          vocabulary.__delay(object_type, args, &block)
        end
      end
    end
  end
end
