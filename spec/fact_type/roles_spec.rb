#
# ActiveFacts tests: Roles of object_type classes in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "Roles" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      class Name < String
        value_type :length => 40, :scale => 0, :restrict => /^[A-Z][a-z0-9]*/
      end
      class Identifier
        identified_by :name
        one_to_one :name
      end
      class LegalEntity
        identified_by :name
        one_to_one :name
      end
      class Contract
        identified_by :first, :second
        has_one :first, :class => LegalEntity
        has_one :second, :class => LegalEntity
      end
      class Person < LegalEntity
        # identified_by         # No identifier needed, inherit from superclass
        # New identifier:
        identified_by :family, :name
        has_one :family, :class => Name
        alias :given :name
        alias :given= :name=
        has_one :related_to, :class => LegalEntity
      end
      class Employee
        identified_by :name
        one_to_one :identifier
        one_to_one :name
      end
    end
    # print "object_type: "; p Mod.object_type
  end

  it "should associate a role name with a matching existing object_type" do
    module Mod
      class Existing1 < String
        value_type
        has_one :name
      end
    end
    role = Mod::Existing1.all_role(:name)
    role.should_not be_nil
    role.inspect.class.should == String
    role.counterpart.object_type.should == Mod::Name
  end

  it "should prevent association of a role name with an object_type from the wrong module" do
    lambda {
      module Mod2
        class Unrelated
        end
      end

      module Mod
        class Existing1 < String
          value_type
          has_one :unrelated, :class => Mod2::Unrelated
        end
      end
    }.should raise_error(ActiveFacts::API::CrossVocabularyRoleException)
  end

  it "should prevent association of a role name with a non-object_type" do
    lambda {
      module Mod
        class NonObject
        end
        class Existing1 < String
          value_type
          has_one :non_object, :class => NonObject
        end
      end
    }.should raise_error(ActiveFacts::API::CrossVocabularyRoleException)
  end

  it "should prevent association of a role name with an implied non-object_type" do
    lambda {
      module Mod
        class NonObject
        end
        class Existing1 < String
          value_type
          has_one :non_object
        end
      end
    }.should raise_error(ActiveFacts::API::CrossVocabularyRoleException)
  end

  it "should prevent usage of undefined options on a role" do
    lambda {
      module Mod
        class Existing1 < String
          value_type
          has_one :name, :foo => :anything
        end
      end
    }.should raise_error(ActiveFacts::API::UnrecognisedOptionsException)

    lambda {
      module Mod
        class Existing1 < String
          value_type
          one_to_one :name, :foo => :anything
        end
      end
    }.should raise_error(ActiveFacts::API::UnrecognisedOptionsException)

    lambda {
      module Mod
        class Existing1 < String
          value_type
          maybe :is_broken, :foo => :anything
        end
      end
    }.should raise_error(ActiveFacts::API::UnrecognisedOptionsException)
  end

  it "should provide value type metadata" do
    Mod::Name.length.should == 40
    Mod::Name.scale.should == 0
  end

  it "should inject the respective role name into the matching object_type" do
    module Mod
      class Existing1 < String
        value_type
        has_one :name
      end
    end
    # REVISIT: need to make more tests for the class's role accessor methods:
    Mod::Name.all_role(:all_existing1).should == Mod::Name.all_existing1_role

    Mod::Name.all_role(:all_existing1).should_not be_nil
    Mod::LegalEntity.all_role(:all_contract_as_first).should_not be_nil
  end

  it "should associate a role name with a matching object_type after it's created" do
    module Mod
      class Existing2 < String
        value_type
        has_one :given_name
      end
    end
    # print "Mod::Existing2.all_role = "; p Mod::Existing2.all_role
    r = Mod::Existing2.all_role(:given_name)
    r.should_not be_nil
    r.counterpart.should be_nil
    module Mod
      class GivenName < String
        value_type
      end
    end
    # puts "Should resolve now:"
    r = Mod::Existing2.all_role(:given_name)
    r.should_not be_nil
    r.counterpart.object_type.should == Mod::GivenName
  end

  it "should handle subtyping a value type" do
    module Mod
      class FamilyName < Name
        value_type
        one_to_one :patriarch, :class => Person
      end
    end
    r = Mod::FamilyName.all_role(:patriarch)
    r.should_not be_nil
    r.counterpart.object_type.should == Mod::Person
    r.counterpart.object_type.all_role(:family_name_as_patriarch).counterpart.object_type.should == Mod::FamilyName
  end

  it "should instantiate the matching object_type on assignment" do
    c = ActiveFacts::API::Constellation.new(Mod)
    bloggs = c.LegalEntity("Bloggs")
    acme = c.LegalEntity("Acme, Inc")
    contract = c.Contract("Bloggs", acme)
    #contract = c.Contract("Bloggs", "Acme, Inc")
    contract.first.should == bloggs
    contract.second.should == acme
    end

  it "should append the counterpart into the respective role array in the matching object_type" do
    c = ActiveFacts::API::Constellation.new(Mod)
    foo = c.Name("Foo")
    le = c.LegalEntity(foo)
    le.respond_to?(:name).should be_true
    name = le.name
    name.respond_to?(:legal_entity).should be_true

    #pending
    [name.legal_entity].should === [le]
  end

  it "should instantiate subclasses sensibly" do
    c = ActiveFacts::API::Constellation.new(Mod)
    bloggs = c.LegalEntity("Bloggs & Co")
    p = c.Person("Fred", "Bloggs")
    p.related_to = "Bloggs & Co"
    p.related_to.should be_an_instance_of Mod::LegalEntity
    p.related_to.should == bloggs

    # REVISIT: The raw instance doesn't override == to compare itself to a RoleProxy unfortunately...
    # So this test succeeds when we'd like it to fail
    #bloggs.should_not == p.related_to
  end

  it "should forward missing methods on the role proxies" do
   c = ActiveFacts::API::Constellation.new(Mod)
   p = c.Person("Fred", "Bloggs")
   lambda {p.family.foo}.should raise_error(NoMethodError)
  end

  it "should forward re-raise exceptions from missing methods on the role proxies" do
    c = ActiveFacts::API::Constellation.new(Mod)
    p = c.Person("Fred", "Bloggs")
    class String
      def foo
        raise "Yawning"
      end
    end

    lambda {p.family.foo}.should raise_error(RuntimeError)
  end

  it "should be able to import an entity from another constellation" do
    c1 = ActiveFacts::API::Constellation.new(Mod)
    c2 = ActiveFacts::API::Constellation.new(Mod)

    e = c1.Employee("PuppetMaster")
    identifier = c2.Identifier "Project2501", :employee => e
    identifier.employee.name.should == "PuppetMaster"
  end

  it "should create TypeInheritance fact type and roles" do
    module Mod
      class GivenName < Name
      end
      class Document
	identified_by :name
	one_to_one :name
      end
      class Contract
	supertypes Document
      end
    end
    [Mod::GivenName, Mod::Person, Mod::Contract].each do |subtype|
      subtype.supertypes.each do |supertype|
	# Get the role names:
	supertype_role_name = supertype.name.gsub(/.*::/,'').to_sym
	subtype_role_name = subtype.name.gsub(/.*::/,'').to_sym

	# Check that the roles are indexed:
	subtype.all_role.should include(supertype_role_name)
	supertype.all_role.should include(subtype_role_name)

	# Get the role objects:
	supertype_role = subtype.all_role[supertype_role_name]
	subtype_role = supertype.all_role[subtype_role_name]

	# Check uniqueness and mandatory:
	supertype_role.unique.should be_true
	subtype_role.unique.should be_true
	supertype_role.mandatory.should be_true
	subtype_role.mandatory.should be_false

	# Check they belong to the same TypeInheritanceFactType:
	subtype_role.fact_type.class.should be(ActiveFacts::API::TypeInheritanceFactType)
	subtype_role.fact_type.should == supertype_role.fact_type
      end
    end
  end

end
