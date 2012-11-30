#
# ActiveFacts tests: Metadata in the Runtime API
# Copyright (c) 2012 Clifford Heath. Read the LICENSE file.
#
require 'activefacts/api'

describe "In a vocabulary" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
    end
    # @constellation = ActiveFacts::API::Constellation.new(Mod)
  end

  ObjectType_methods = [
    :has_one, :is_a?, :maybe, :one_to_one,
    :roles, :subtypes, :supertypes, :vocabulary,
    # To make private:
    :detect_fact_type_collision, :realise_role, :supertypes_transitive,
  ]

  ValueType_methods = [
    :assert_instance, :identifying_role_values, :index_instance,
    :inherited, :length, :restrict, :scale, :value_type, :verbalise
  ]

  Instance_methods = [
    :constellation, :retract,
    # To make private:
    :constellation=,
    # To remove or move to EntityType
    :related_entities, :detect_inconsistencies, :duplicate_identifying_values?,
    :instance_index, :instance_index_counterpart, :is_identified_by?, :is_unique?,
  ]
  Value_methods = Instance_methods + [
    :verbalise, :identifying_role_values
  ]

  EntityType_methods = [
    :assert_instance, :identified_by,
    :identifying_role_names, :identifying_role_values, :identifying_roles,
    :index_instance, :inherited,
    :verbalise,
    # To make private:
    :assign_additional_roles,
    :identification_inherited_from, :identification_inherited_from=,
    :find_inherited_role,
    :overrides_identification_of, :overrides_identification_of=,
    # To remove
    :created_instances, :created_instances=
  ]

  Entity_methods = Instance_methods + [
    :verbalise, :identifying_role_values,
    # To remove hide or rewrite:
    :identity_by, :identity_as_hash, :settable_roles, :settable_roles_exception,
  ]

  Cases =
    ValueClasses.map do |klass| # [String, Date, DateTime, Time, Int, Real, AutoCounter, Decimal, Guid]
      { :name => "a #{klass}",
	:definition => %Q{
	  class T < #{klass}
	    value_type
	  end
	},
	:pattern => /Method: Class\(ActiveFacts::API::Value::ClassMethods\)#/,
	:class_methods => ValueType_methods,
	:instance_methods => Value_methods,
	:constructor_args => Array(
	  case klass.name
	  when /String/; 'foo'
	  when /DateTime/; [2008, 04, 20, 10, 28, 14]
	  when /Date\E/; '2012-12-11'
	  when /Time*/; '10:11:12'
	  when /Int/; 23
	  when /Real/; 23.45
	  when /AutoCounter/, /Guid/; :new
	  when /Decimal/; '12345.5678'
	  end
	).compact
      }
    end + [
      { :name => "a Value Sub Type",
	:definition => %q{
	  class V < String
	    value_type
	  end
	  class T < V
	  end
	},
	:pattern => /Method: Class\(ActiveFacts::API::Value::ClassMethods\)#/,
	:class_methods => ValueType_methods,
	:instance_methods => Value_methods,
	:constructor_args => [ 'foo' ]
      },

      { :name => "an Entity Type",
	:definition => %q{
	  class V < String
	    value_type
	  end
	  class T
	    identified_by :foo
	    one_to_one :foo, :class => V
	  end
	},
	:pattern => /Method: Class\(ActiveFacts::API::Entity::ClassMethods\)#/,
	:class_methods => EntityType_methods,
	:instance_methods => Entity_methods,
	:constructor_args => [ 'foo' ]
      },

      { :name => "an Entity Sub Type",
	:definition => %q{
	  class V < String
	    value_type
	  end
	  class E
	    identified_by :foo
	    one_to_one :foo, :class => V
	  end
	  class T < E
	  end
	},
	:pattern => /Method: Class\(ActiveFacts::API::Entity::ClassMethods\)#/,
	:class_methods => EntityType_methods,
	:instance_methods => Entity_methods,
	:constructor_args => [ 'foo' ]
      },

      { :name => "an Entity Sub Type with independent identification",
	:definition => %q{
	  class V < String
	    value_type
	  end
	  class E
	    identified_by :foo
	    one_to_one :foo, :class => V
	  end
	  class T < E
	    identified_by :bar
	    one_to_one :bar, :class => V
	  end
	},
	:pattern => /Method: Class\(ActiveFacts::API::Entity::ClassMethods\)#/,
	:class_methods => EntityType_methods,
	:instance_methods => Entity_methods,
	:constructor_args => [ 'bar', {:foo => 'foo'} ]
      },

      { :name => "an Entity Sub Type with extra supertypes",
	:definition => %q{
	  class V < String
	    value_type
	  end
	  class E
	    identified_by :foo
	    one_to_one :foo, :class => V
	  end
	  class E2
	    identified_by :baz
	    one_to_one :baz, :class => V
	  end
	  class T < E
	    supertypes E2
	    one_to_one :bar, :class => V
	  end
	},
	:pattern => /Method: Class\(ActiveFacts::API::Entity::ClassMethods\)#/,
	:class_methods => EntityType_methods,
	:instance_methods => Entity_methods,
	:constructor_args => [ 'bar', {:foo => 'foo', :baz => 'baz'} ]
      },

    ]

  Cases.each do |casehash|
    case_name = casehash[:name]
    definition = "module Mod; "+ casehash[:definition] + "; end"
    pattern = casehash[:pattern]
    class_methods = casehash[:class_methods]
    instance_methods = casehash[:instance_methods]
    constructor_args = casehash[:constructor_args]

    describe "#{case_name}" do
      before :each do
	eval definition
	all_T_methods = Mod::T.methods.select{|m| Mod::T.method(m).inspect =~ /ActiveFacts/}.sort
	@object_type_methods, @value_type_methods =
	  *all_T_methods.partition do |m|
	    Mod::T.method(m).inspect =~ /Method: Class\(ActiveFacts::API::ObjectType\)#/
	  end
      end

      describe "as an ObjectType" do
	it "should have the appropriate class methods" do
	  @object_type_methods.should == ObjectType_methods.sort
	end

	ObjectType_methods.each do |m|
	  it "should respond to ObjectType.#{m}" do
	    Mod::T.should respond_to(m)
	    Mod::T.method(m).inspect.should =~ /Method: Class\(ActiveFacts::API::ObjectType\)#/
	  end
	end
      end

      describe "as #{case_name}" do
	it "should have the appropriate class methods" do
	  @value_type_methods.should == class_methods.sort
	end

	class_methods.each do |m|
	  it "should respond to #{case_name}.#{m}" do
	    Mod::T.should respond_to(m)
	    Mod::T.method(m).inspect.should =~ pattern
	  end
	end
      end

      describe "An instance of #{case_name}" do
	before :each do
	  v = Mod::T.new(*constructor_args)
	  all_T_instance_methods = v.methods.select{|m| v.method(m).inspect =~ /ActiveFacts/}.sort
	  @instance_methods = (all_T_instance_methods-''.methods).sort
	end

	it "should have the appropriate instance methods" do
	  @instance_methods.should == instance_methods.sort
	end

	instance_methods.each do |m|
	  it "should respond to #{case_name}\##{m}" do
	    v = Mod::T.new(*constructor_args)
	    v.should respond_to(m)
	    if Instance_methods.include?(m)
	      v.method(m).inspect.should =~ /Mod::T\(ActiveFacts::API::Instance\)#/
	    else
	      v.method(m).inspect.should =~ /Mod::T\(ActiveFacts::API::(Value|Entity)\)#/
	    end
	  end
	end
      end
    end
  end
end
