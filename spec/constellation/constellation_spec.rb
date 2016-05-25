#
# ActiveFacts tests: Constellation instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "A Constellation instance" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      @base_types = [
          Int, Real, AutoCounter, String, Date, DateTime, Decimal, Guid
        ]

      # Create a value type and a subtype of that value type for each base type:
      @base_types.each do |base_type|
        Mod.module_eval <<-END
          class #{base_type.basename}Val < #{base_type.name}
            value_type
          end

          class #{base_type.basename}SubVal < #{base_type.name}Val
            # Note no new "value_type" is required here, it comes through inheritance
          end
        END
      end

      class Name < StringVal
        value_type
        #has_one :attr, Name
        has_one :undefined_role         # This will be unsatisfied with the non-existence of the UndefinedRole class
      end

      class LegalEntity
        identified_by :name
        one_to_one :name, :mandatory => true
      end

      class Surrogate
        identified_by :auto_counter_val
        one_to_one :auto_counter_val
      end

      class Company < LegalEntity
        supertypes Surrogate
      end

      class Person < LegalEntity
        identified_by :name, :family_name       # REVISIT: want a way to role_alias :name, :given_name
        supertypes :surrogate                   # Use a Symbol binding this time

        has_one :family_name, :class => Name
        has_one :employer, :class => Company
        one_to_one :birth_name, :class => Name
      end
    end
    @constellation = ActiveFacts::API::Constellation.new(Mod)
  end

  describe "Vocabulary" do
    it "should create the constellation" do
      Mod.constellation.should be_an_instance_of ActiveFacts::API::Constellation
    end

    it "should create the constellation by direct populate" do
      Mod.populate do
        Name "foo"
      end.should be_an_instance_of ActiveFacts::API::Constellation
    end

    it "should verbalise" do
      s = Mod.verbalise
      s.should be_an_instance_of String
    end
  end

  it "should allow creating a constellation" do
    @constellation = ActiveFacts::API::Constellation.new(Mod)
  end

  it "should complain when accessing a non-class as a method" do
    Mod::Foo = 23
    lambda { @constellation.Foo }.should raise_error(NoMethodError)
  end

  it "should complain when accessing a class that isn't an object type" do
    class Mod::Bar; end
    proc { @constellation.Bar }.should raise_error(NoMethodError)
    proc { @constellation.instances[Mod::Bar] }.should raise_error(ActiveFacts::API::InvalidObjectType)
  end

  it "should deny handling an object type defined outside the current module" do
    class ::Bar; end
    lambda { @constellation.Bar }.should raise_error(NoMethodError)
    lambda { @constellation.instances[Bar] }.should raise_error(ActiveFacts::API::InvalidObjectType)
  end

  it "should allow inspection" do
    lambda { @constellation.inspect }.should_not raise_error
  end

  it "should support fetching its vocabulary" do
    @constellation.vocabulary.should == Mod
  end

#  it "should support fetching its query" do
#    pending
#    @constellation.query.should == Mod
#  end

  it "should create methods to assert instances" do
    # Check that methods have not yet been created:
    @constellation.should_not respond_to(:Name)
    @constellation.should_not respond_to(:LegalEntity)
    @constellation.should_not respond_to(:Company)
    @constellation.should_not respond_to(:Person)

    # Assert instances
    name = foo = acme = fred_fly = nil
    lambda {
        name = @constellation.Name("foo")
        foo = @constellation.LegalEntity("foo")
        acme = @constellation.Company("Acme, Inc", :auto_counter_val => :new)
        fred_fly = @constellation.Person("fred", "fly", :auto_counter_val => :new)
    }.should_not raise_error

    # Check that methods have not yet been created:
    @constellation.should respond_to(:Name)
    @constellation.should respond_to(:LegalEntity)
    @constellation.should respond_to(:Company)
    @constellation.should respond_to(:Person)

    # Check the instances
    name.class.should == Mod::Name
    name.constellation.should == @constellation

    foo.class.should == Mod::LegalEntity
    foo.constellation.should == @constellation
    foo.inspect.should =~ /<Mod::LegalEntity name: "foo">/
    foo.verbalise.should =~ /LegalEntity\(/

    acme.class.should == Mod::Company
    acme.constellation.should == @constellation
    acme.inspect.should =~ /<Mod::Company name: "Acme, Inc">/
    acme.verbalise.should =~ /Company\(/

    fred_fly.class.should == Mod::Person
    fred_fly.constellation.should == @constellation
    fred_fly.inspect.should =~ /^<Mod::Person name:/
    fred_fly.verbalise.should =~ /Person\(/
  end

  it "should re-use instances constructed the same way" do
    name1 = @constellation.Name("foo")
    foo1 = @constellation.LegalEntity("foo")
    acme1 = @constellation.Company("Acme, Inc", :auto_counter_val => :new)
    fred_fly1 = @constellation.Person("fred", "fly", :auto_counter_val => :new)

    name2 = @constellation.Name("foo")
    foo2 = @constellation.LegalEntity("foo")
    acme2 = @constellation.Company("Acme, Inc") # , :auto_counter_val => :new)
    fred_fly2 = @constellation.Person("fred", "fly") # , :auto_counter_val => :new)

    name1.object_id.should == name2.object_id
    foo1.object_id.should == foo2.object_id
    acme1.object_id.should == acme2.object_id
    fred_fly1.object_id.should == fred_fly2.object_id
  end

  describe "re-assertion with any one of multiple identifiers" do
    before :each do
      # Create some instances:
      @name1 = @constellation.Name("foo")               # Value type
      @foo1 = @constellation.LegalEntity("foo") # Entity Type with simple identifier
      @acme1 = @constellation.Company("Acme, Inc", :auto_counter_val => :new)
      @acme1_id = @acme1.auto_counter_val
    end

    it "should be allowed with a normal value type id" do
      # Reassert the instances:
      @name2 = @constellation.Name("foo")
      @foo2 = @constellation.LegalEntity("foo")
      @acme2 = nil
      lambda {
        # Without the auto_counter_val
        @acme2 = @constellation.Company("Acme, Inc")
      }.should_not raise_error

      # This creates a new auto_counter_val, changing the acme instance (and hence, both references to it)
      @acme2.auto_counter_val = :new
      @acme2.should == @acme1
      @acme2.auto_counter_val.should_not be_defined
      @acme2.auto_counter_val.to_s.should_not == @acme1_id.to_s
    end

    it "should be allowed with an autocounter id" do
      acme3 = @constellation.Surrogate(@acme1_id)
      acme3.should == @acme1
    end
  end

  it "Should raise an exception with assigning a role whose referent (object type) has not yet been defined" do
    n = @constellation.Name("Fred")
    # This does not raise the "settable_roles_exception". I'm no longer sure how I did this, so I can't get coverage on this code :(
    proc { n.undefined_role = 'foo' }.should raise_error(NoMethodError)
  end

  # Maybe not complete yet
  describe "assigning additional arguments on asserting a value type" do
    before :each do
      # This should work, but...
      # birth_name = @constellation.Name("Smith", :person_as_birth_name => {:name => "Janet", :family_name => "Jones", :auto_counter_val => :new})
      # for now, use the following form
      @birth_name = @constellation.Name("Smith", :person_as_birth_name => ["Janet", "Jones", {:auto_counter_val => :new}])
      @person = @birth_name.person_as_birth_name
    end

    it "should create required instances" do
      @person.should_not be_nil
      @person.family_name.should == "Jones"
      @person.name.should == "Janet"
      @person.birth_name.should == "Smith"
    end

    it "should initialise secondary supertypes" do
      @acv = @person.auto_counter_val
      @acv.should_not be_nil
      @acv.surrogate.should == @person
    end
  end

  it "should support population blocks" do
    @constellation.populate do
      Name("bar")
      LegalEntity("foo")
      Person("Fred", "Nerk", :auto_counter_val => :new)
      Company("Acme, Inc", :auto_counter_val => :new)
    end
    @constellation.Name.size.should == 5
    @constellation.Surrogate.size.should == 2
  end

  it "should verbalise itself" do
    @constellation.populate do
      Name("bar")
      LegalEntity("foo")
      c = Company("Acme, Inc", :auto_counter_val => :new)
      c.is_a?(Mod::Surrogate).should == true
      c.auto_counter_val.should_not == nil
      p = Person("Fred", "Nerk", :auto_counter_val => :new)
      p.employer = c
      p.birth_name = "Nerk"
    end
    s = @constellation.verbalise
    names = s.split(/\n/).grep(/\tEvery /).map{|l| l.sub(/.*Every (.*):$/, '\1')}
    expected = ["Company", "LegalEntity", "Name", "Person", "StringVal", "Surrogate"]
    names.sort.should == expected
  end

  it "should support string capitalisation functions" do
    names = ["Company", "LegalEntity", "Name", "Person", "StringVal", "Surrogate"]
    camelwords = names.map{|n| n.camelwords }
    camelwords.should == [["Company"], ["Legal", "Entity"], ["Name"], ["Person"], ["String", "Val"], ["Surrogate"]]

    snakes = names.map{|n| n.snakecase }
    snakes.should == ["company", "legal_entity", "name", "person", "string_val", "surrogate"]

    camelupper = snakes.map{|n| n.camelcase }
    camelupper.should == ["Company", "LegalEntity", "Name", "Person", "StringVal", "Surrogate"]

    camellower = snakes.map{|n| n.camelcase(:lower) }
    camellower.should == ["company", "legalEntity", "name", "person", "stringVal", "surrogate"]
  end

  it "should allow inspection of instance indices" do
    baz = @constellation.Name("baz")
    @constellation.Name.inspect.class.should == String
  end

  it "should index value instances, including by its superclasses" do
    baz = @constellation.Name("baz")
    @constellation.Name.keys.sort.should == ["baz"]

    @constellation.StringVal.keys.sort.should == ["baz"]
    @constellation.StringVal[baz].should == baz
    @constellation.StringVal["baz"].should == baz
  end

  describe "instance indices" do
    it "should support each" do
      baz = @constellation.Name("baz")
      count = 0
      @constellation.Name.each { |k, v| count += 1 }
      count.should == 1
    end

    it "should support detect" do
      baz = @constellation.Name("baz")
      @constellation.Name.detect { |rv| true }.should be_truthy
    end
  end

  it "should index entity instances, including by its superclass and secondary supertypes" do
    name = "Acme, Inc"
    fred = "Fred"
    fly = "Fly"
    acme = @constellation.Company name, :auto_counter_val => :new
    fred_fly = @constellation.Person fred, fly, :auto_counter_val => :new

    # REVISIT: This should be illegal:
    #fred_fly.auto_counter_val = :new

    @constellation.Person.keys.sort.should == [[fred, fly]]
    @constellation.Company.keys.sort.should == [[name]]

    @constellation.LegalEntity.keys.sort.should include [name]
    @constellation.LegalEntity.keys.sort.should include [fred]

    @constellation.Surrogate.values.should include acme
    @constellation.Surrogate.values.should include fred_fly
  end

  it "should handle one-to-ones correctly" do
    person = @constellation.Person "Fred", "Smith", :auto_counter_val => :new, :birth_name => "Nerk"

    nerk = @constellation.Name["Nerk"]
    nerk.should_not be_nil
    nerk.person_as_birth_name.should == person
    person.birth_name = nil
    nerk.person_as_birth_name.should be_nil
    @constellation.Name["Nerk"].should_not be_nil
  end

  it "should allow retraction of instances" do
    @constellation.Person
    person = @constellation.Person "Fred", "Smith", :auto_counter_val => :new, :birth_name => "Nerk"
    smith = @constellation.Name("Smith")

    # Check things are indexed properly:
    @constellation.Surrogate.size.should == 1
    @constellation.LegalEntity.size.should == 1
    @constellation.Person.size.should == 1
    person.family_name.should == smith
    smith.all_person_as_family_name.size.should == 1

    @constellation.retract(smith)

    @constellation.Name["Fred"].should_not be_nil   # FamilyName is not mandatory, so Fred still exists
    @constellation.Name["Smith"].should be_nil

    @constellation.Surrogate.size.should == 1
    @constellation.LegalEntity.size.should == 1
    @constellation.Person.size.should == 1

    person.family_name.should be_nil

    smith.all_person_as_family_name.size.should == 0
  end

  it "should retract linked instances (cascading)" do
    fred = @constellation.Person "Fred", "Smith", :auto_counter_val => :new, :birth_name => "Nerk"
    george = @constellation.Person "George", "Smith", :auto_counter_val => :new, :birth_name => "Patrick"
    smith = @constellation.Name("Smith")

    @constellation.Person.size.should == 2
    fred.family_name.should == smith
    george.family_name.should == smith
    smith.all_person_as_family_name.size.should == 2

    @constellation.retract(fred)

    @constellation.Person.size.should == 1        # Fred is gone, George still exists
    @constellation.Person.values[0].name.should == 'George'
    fred.family_name.should be_nil
    smith.all_person_as_family_name.size.should == 1
  end

  it "should retract linked sets of instances (cascading)" do
    skip "Test not yet written"
  end

  it "should fail to recognise references to unresolved forward referenced classes" do
    module Mod2
      class Foo
        identified_by :name
        one_to_one :name
        has_one :not_yet
        has_one :baz, :class => "BAZ"
      end

      class Name < String
        value_type
      end
    end

    @c = ActiveFacts::API::Constellation.new(Mod2)
    le = @c.Foo("Foo")
    lambda {
      le.not_yet
    }.should raise_error(NoMethodError)
    lambda {
      le.baz
    }.should raise_error(NoMethodError)

    # Now define the classes and try again:
    module Mod2
      class NotYet < String
        value_type
      end
      class BAZ < String
        value_type
      end
    end
    lambda {
      le.not_yet
      le.not_yet = 'not_yet'
    }.should_not raise_error
    lambda {
      le.baz
      le.baz = 'baz'
    }.should_not raise_error
  end

  it "should not allow references to classes outside the vocabulary" do
    module Outside
      class Other < String
        value_type
      end
    end

    lambda {
      module Mod
        class IntVal
          has_one :thingummy, :class => Outside::Other
        end
      end
    }.should raise_error(ActiveFacts::API::CrossVocabularyRoleException)
  end

  it "should disallow unrecognised supertypes" do
    lambda {
      module Mod
        class LegalEntity
          supertypes :foo
        end
      end
    }.should raise_error(NameError)

    lambda {
      module Mod
        class LegalEntity
          supertypes Bignum
        end
      end
    }.should raise_error(ActiveFacts::API::InvalidSupertypeException)

    lambda {
      module Mod
        class LegalEntity
          supertypes 3
        end
      end
    }.should raise_error(ActiveFacts::API::InvalidSupertypeException)
  end

  it "should allow supertypes with supertypes" do
    lambda {
      module Mod
        class ListedCompany < Company
        end
      end
      c = @constellation.ListedCompany("foo", :auto_counter_val => 23)
    }.should_not raise_error
  end

  it "should be able to attach a new supertype on an entity type to make it a (sub-)subtype" do
    module Mod
      class Dad
        identified_by :name
      end
      class Son < Dad
        identified_by :name
      end
      # the grand son will be linked on the fly
      class GrandSon
        identified_by :name
      end
    end
    Mod::GrandSon.supertypes(Mod::Son)
    Mod::GrandSon.supertypes.should include Mod::Son
    Mod::Son.supertypes.should include Mod::Dad
  end

  it "should keep information on where the identification came from" do
    module Mod
      class Dad
        identified_by :name
      end
      class Son < Dad
        identified_by :name
      end
      # Note the inheritance.
      class GrandSon < Son
        identified_by :name
      end
    end

    Mod::Son.identification_inherited_from.should == Mod::Dad
    Mod::Son.identification_inherited_from.should == Mod::Dad
    Mod::GrandSon.identification_inherited_from.should == Mod::Son
    Mod::GrandSon.overrides_identification_of.should == Mod::Dad
  end

  it "should disallow using a value type as a supertypes for an entity type" do
    lambda {
      module Mod
        class CompanyName
          identified_by :name
          supertypes :name
        end
      end
    }.should raise_error(ActiveFacts::API::InvalidSupertypeException)
  end

  it "should error on invalid :class values" do
    lambda {
      module Mod
        class Surrogate
          has_one :Name, :class => 3
        end
      end
    }.should raise_error(ArgumentError)
  end

  it "should error on misleading :class values" do
    lambda {
      module Mod
        class Surrogate
          has_one :Name, :class => Extra
        end
      end
    }.should raise_error(NameError)
  end

  it "should allow assert using an object of the same type" do
    c = @constellation.Company("foo", :auto_counter_val => 23)
    c2 = ActiveFacts::API::Constellation.new(Mod)
    lambda {
      c2.Company(c, :auto_counter_val => :new)
    }.should_not raise_error
    c2.Company.keys.should == [["foo"]]
  end

  it "should allow cross-constellation construction" do
    c = @constellation.Company("foo", :auto_counter_val => 23)
    lambda {
      c2 = ActiveFacts::API::Constellation.new(Mod)
      c2.Company(c.name, :auto_counter_val => :new)
    }.should_not raise_error
  end

  it "should copy values during cross-constellation assignment" do
    c = @constellation.Company("foo", :auto_counter_val => 23)

    # Now make a new constellation and use the above values to initialise new instances
    p = nil
    lambda {
      c2 = ActiveFacts::API::Constellation.new(Mod)
      p = c2.Person('Fred', 'Smith', :auto_counter_val => :new)
      p.employer = [ c.name, {:auto_counter_val => c.auto_counter_val}]
    }.should_not raise_error
    c.auto_counter_val.should_not === p.employer.auto_counter_val
    c.auto_counter_val.should_not == p.employer.auto_counter_val
    c.auto_counter_val.to_s.should == p.employer.auto_counter_val.to_s
    p.employer.should_not === c

    lambda {
      # Disallowed because it re-assigns the auto_counter_val identification value
      p.employer = [ "foo", {:auto_counter_val => :new}]
    }.should raise_error(ActiveFacts::API::TypeConflictException)
  end
end
