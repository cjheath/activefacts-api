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
      # What vocabulary (Ruby module) does this object_type belong to?
      def vocabulary
        modspace        # The module that contains this object_type.
      end

      # Each ObjectType maintains a list of the Roles it plays:
      def roles(role_name = nil)
        unless instance_variable_defined? "@roles"
          @roles = RoleCollection.new     # Initialize and extend without warnings.
        end
        case role_name
        when nil
          @roles
        when Symbol, String
          # Search this class then all supertypes:
          unless role = @roles[role_name.to_sym]
            role = nil
            supertypes.each do |supertype|
                begin
                  role = supertype.roles(role_name)
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

      # Define a unary fact type attached to this object_type; in essence, a boolean attribute.
      #
      # Example: maybe :is_ceo
      def maybe(role_name)
        realise_role(roles[role_name] = Role.new(self, TrueClass, role_name))
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
              raise "Entity type #{self} cannot be identified by a single role '#{role}' unless that role is one_to_one"
            end
          when :one_to_one
            if identifying_role_names.size > 1
              raise "Entity type #{self} cannot be identified by a single role '#{role}' unless that role is has_one"
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
	      raise "Illegal supertype #{object_type.inspect} for #{self.class.basename}"
	    end
	  raise "#{supertype.name} must be an object type in #{vocabulary.name}" unless supertype.respond_to?(:vocabulary) and supertype.vocabulary == self.vocabulary

	  if is_entity_type != supertype.is_entity_type
	    raise "#{self} < #{supertype}: A value type may not be a supertype of an entity type, and vice versa"
	  end

	  @supertypes << supertype

	  # Realise the roles (create accessors) of this supertype.
	  # REVISIT: The existing accessors at the other end will need to allow this class as role counterpart
	  # REVISIT: Need to check all superclass roles recursively, unless we hit a common supertype
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

      # Every new role added or inherited comes through here:
      def realise_role(role) #:nodoc:
        if (role.is_unary)
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
        object_type.roles.each do |role_name, role|
          realise_role(role)
        end
      end

      # Shared code for both kinds of binary fact type (has_one and one_to_one)
      def define_binary_fact_type(one_to_one, role_name, related, mandatory, related_role_name)
        # REVISIT: What if the role exists on a supertype? This won't prevent that:
        raise "#{name} cannot have more than one role named #{role_name}" if roles[role_name]
        roles[role_name] = role = Role.new(self, nil, role_name, mandatory)

        # There may be a forward reference here where role_name is a Symbol,
        # and the block runs later when that Symbol is bound to the object_type.
        when_bound(related, self, role_name, related_role_name) do |target, definer, role_name, related_role_name|
          if (one_to_one)
            target.roles[related_role_name] = role.counterpart = Role.new(target, role, related_role_name, false)
          else
            target.roles[related_role_name] = role.counterpart = Role.new(target, role, related_role_name, false, false)
          end
          realise_role(role)
          target.realise_role(role.counterpart)
        end
      end

      def define_unary_role_accessor(role)
	define_method role.setter do |value|
	  assigned = case value
	    when nil; nil
	    when false; false
	    else true
	    end
	  instance_variable_set(role.variable, assigned)
	  # REVISIT: Provide a way to find all instances playing/not playing this role
	  # Analogous to true.all_thing_as_role_name...
	  assigned
	end
        define_single_role_getter(role)
      end

      def define_single_role_getter(role)
	define_method role.getter do |*a|
	  raise "Parameters passed to #{self.class.name}\##{role.name}" if a.size > 0
	  instance_variable_get(role.variable)
	end
      end

      def define_one_to_one_accessor(role)
        define_single_role_getter(role)

	define_method role.setter do |value|
	  old = instance_variable_get(role.variable)

	  # When exactly the same value instance is assigned, we're done:
	  return true if old.equal?(value)

	  if @constellation and value and o = role.counterpart.object_type and (!value.is_a?(o) || value.constellation != @constellation)
	    value = @constellation.assert(o, value)
	    return true if old.equal?(value)         # Occurs when same value but not same instance is assigned
	  end

	  dependent_entities = nil
	  if (role.is_identifying)
#	    detect_inconsistencies(role, value)

	    # Find all object instances whose keys are dependent on this object's key
	    if @constellation && old
	      dependent_entities = old.related_entities.map do |entity|
		[entity.identifying_role_values, entity]
	      end
	    end
	  end

	  instance_variable_set(role.variable, value)

	  # Remove self from the old counterpart:
	  old.send(role.counterpart.setter, nil) if old

	  # REVISIT: Delay co-referencing here if the object is still a candidate
	  if @constellation
	    # Assign self to the new counterpart
	    value.send(role.counterpart.setter, self) if value

	    # Propagate dependent key changes
	    if dependent_entities
	      dependent_entities.each do |old_key, entity|
		entity.instance_index.refresh_key(old_key)
	      end
	    end
	  end

	  value
	end
      end

      def define_one_to_many_accessor(role)
        define_single_role_getter(role)

	define_method role.setter do |value|
	  role_var = role.variable

	  # Get old value, and jump out early if it's unchanged:
	  old = instance_variable_get(role_var)
	  return value if old.equal?(value)         # Occurs during one_to_one assignment, for example

	  if @constellation and value and o = role.counterpart.object_type and (!value.is_a?(o) || value.constellation != @constellation)
	    value = @constellation.assert(o, value)
	    return value if old.equal?(value)         # Occurs when another instance having the same value is assigned
	  end

	  dependent_entities = nil
	  if (role.is_identifying)
#	    detect_inconsistencies(role, value) if value

	    if old && old.constellation
	      # If our identity has changed and we identify others, prepare to reindex them
	      dependent_entities = old.related_entities.map do |entity|
		[entity.identifying_role_values, entity]
	      end
	    end
	  end

	  instance_variable_set(role_var, value)

	  # Remove "self" from the old counterpart:
	  old.send(getter = role.counterpart.getter).update(self, nil) if old

	  if @constellation
	    # REVISIT: Delay co-referencing here if the object is still a candidate
	    # Add "self" into the counterpart
	    value.send(getter ||= role.counterpart.getter).update(old, self) if value

	    if dependent_entities
	      dependent_entities.each do |key, entity|
		entity.instance_index.refresh_key(key)
	      end
	    end
	  end

	  value
	end
      end

      def define_many_to_one_accessor(role)
	define_method role.getter do
	  role_var = role.variable
	  instance_variable_get(role_var) or
	    instance_variable_set(role_var, RoleValues.new)
        end
      end

      # Extract the parameters to a role definition and massage them into the right shape.
      #
      # The first parameter, role_name, is mandatory. It may be a Symbol, a String or a Class.
      # New proposed input options:
      # :class => the related class (Class object or Symbol). Not allowed if role_name was a class.
      # :mandatory => true. There must be a related object for this object to be valid.
      # :counterpart => Symbol/String. The name of the counterpart role. Will be to_s.snakecase'd and maybe augmented with "all_" and/or "_as_<role_name>"
      # :reading => "forward/reverse". Forward and reverse readings. Must include MARKERS for the player names. May include adjectives. REVISIT: define MARKERS!
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
        related_name = options.delete(:class)
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
          raise "Invalid type for :class option on :#{role_name}"
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

        reading = options.delete(:reading)        # REVISIT: Implement verbalisation
        role_value_constraint = options.delete(:restrict)   # REVISIT: Implement role value constraints

        raise "Unrecognised options on #{role_name}: #{options.keys.inspect}" unless options.empty?

        # Avoid a confusing mismatch:
        # Note that if you have a role "supervisor" and a sub-class "Supervisor", this'll bitch.
        if (Class === related && (indicated = vocabulary.object_type(role_name)) && indicated != related)
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
