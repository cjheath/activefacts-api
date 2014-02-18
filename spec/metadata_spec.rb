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
    @constellation = ActiveFacts::API::Constellation.new(Mod)
  end

  ObjectType_methods = [
    :has_one, :maybe, :one_to_one,
    :add_role, :all_role, :subtypes, :supertypes, :vocabulary,
    :all_role_transitive,
    # To make private:
    :check_identifying_role_has_valid_cardinality, :realise_role, :supertypes_transitive,
  ]

  ValueType_methods = [
    :assert_instance, :identifying_role_values, :index_instance,
    :inherited, :length, :restrict, :scale, :value_type, :verbalise
  ]

  Instance_methods = [
    :constellation, :retract, :is_a?,
    # To remove or move to EntityType
    :related_entities, :check_identification_change_legality,
    :instance_index
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
    :check_no_supertype_instance_exists, :check_supertype_identifiers_match,
    :identification_inherited_from, :identification_inherited_from=,
    :find_inherited_role,
    :overrides_identification_of, :overrides_identification_of=,
    # To remove
    :created_instances, :created_instances=
  ]

  Entity_methods = Instance_methods + [
    :verbalise, :identifying_role_values,
    # To remove hide or rewrite:
    :identity_by, :identity_as_hash
  ]

  Cases =
    ValueClasses.map do |klass| # [String, Date, DateTime, Int, Real, AutoCounter, Decimal, Guid]
      { :name => "a #{klass}",
	:definition => %Q{
	  class T < #{klass}
	    value_type
	  end
	},
	:pattern => /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Value::ClassMethods[) ]/,
	:class_methods => ValueType_methods,
	:instance_methods => Value_methods,
	:constructor_args => Array(
	  case klass.name
	  when 'String'; 'foo'
	  when 'DateTime'; [2008, 04, 20, 10, 28, 14]
	  when 'Date'; '2012-12-11'
	  when 'Time'; [2008, 04, 20, 10, 28, 14]
	  when 'Int'; 23
	  when 'Real'; 23.45
	  when 'AutoCounter', 'Guid'; :new
	  when 'Decimal'; '12345.5678'
	  else
	    raise "Please define constructor args for #{klass}"
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
	:pattern => /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Value::ClassMethods[) ]/,
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
	:pattern => /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Entity::ClassMethods[) ]/,
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
	:pattern => /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Entity::ClassMethods[) ]/,
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
	:pattern => /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Entity::ClassMethods[) ]/,
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
	:pattern => /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Entity::ClassMethods[) ]/,
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
	all_T_methods = Mod::T.methods.select{|m| Mod::T.method(m).inspect =~ /ActiveFacts/}.map(&:to_s).sort
	@object_type_methods, @value_type_methods =
	  *all_T_methods.partition do |m|
	    Mod::T.method(m).inspect =~ /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::ObjectType[) ]/
	  end
      end

      describe "as an ObjectType" do
	it "should have the appropriate class methods" do
	  @object_type_methods.should == ObjectType_methods.map(&:to_s).sort
	end

	ObjectType_methods.each do |m|
	  it "should respond to ObjectType.#{m}" do
	    Mod::T.should respond_to(m)
	    Mod::T.method(m).inspect.should =~ /Method: Class(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::ObjectType[) ]/
	  end
	end
      end

      describe "as #{case_name}" do
	it "should have the appropriate class methods" do
	  @value_type_methods.should == class_methods.map(&:to_s).sort
	end

	class_methods.each do |m|
	  it "should respond to #{case_name}.#{m}" do
	    Mod::T.should respond_to(m)
	    Mod::T.method(m).inspect.should =~ pattern
	  end
	end
      end

      describe "when instantiated" do
	before :each do
	  @instance = @constellation.T(*constructor_args)
	end

	it "should be ok" do
	  @instance.should_not be_nil
	end

	if @instance
	end
      end

      describe "An instance of #{case_name}" do
	before :each do
	  @v = @constellation.T(*constructor_args)
	  all_T_instance_methods = @v.methods.select do |m|
	      i = @v.method(m).inspect
	      i =~ /ActiveFacts/ || i =~ /identifying_role_values/
	    end.sort.map(&:to_sym)
	  @actual_instance_methods = all_T_instance_methods
	end

	it "should have the appropriate instance methods" do
	  # @actual_instance_methods.should == instance_methods.map(&:to_s).sort
	  # Weaken our expectation to just that nothing should be missing (extra methods are ok)
	  missing_methods = instance_methods - @actual_instance_methods
	  missing_methods.should == []
	end

	instance_methods.each do |m|
	  it "should respond to #{case_name}\##{m}" do
	    v = @constellation.T(*constructor_args)
	    v.should respond_to(m)
	    if Instance_methods.include?(m)
	      v.method(m).inspect.should =~ /Mod::T(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::Instance[) ]/
	    else
	      v.method(m).inspect.should =~ /Mod::T(#[a-z_0-9]*[?=]? )?\((defined in )?ActiveFacts::API::(Value|Entity)[) ]/
	    end
	  end
	end
      end
    end
  end
end
