#
# ActiveFacts tests: Constellation instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

require 'rspec'
require 'activefacts/api'

describe "A Constellation instance" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      @base_types = [
          Int, Real, AutoCounter, String, Date, DateTime
        ]

      # Create a value type and a subtype of that value type for each base type:
      @base_types.each do |base_type|
        eval <<-END
          class #{base_type.basename}Value < #{base_type.name}
            value_type
          end

          class #{base_type.basename}SubValue < #{base_type.name}Value
            # Note no new "value_type" is required here, it comes through inheritance
          end
        END
      end

      class Name < StringValue
        value_type
        #has_one :attr, Name
      end

      class LegalEntity
        identified_by :name
        has_one :name, :mandatory => true
      end

      class SurrogateId
        identified_by :auto_counter_value
        has_one :auto_counter_value
      end

      class Company < LegalEntity
        supertypes SurrogateId
      end

      class Person < LegalEntity
        identified_by :name, :family_name     # REVISIT: want a way to role_alias :name, :given_name
        supertypes SurrogateId

        has_one :family_name, :class => Name
        has_one :employer, :class => Company
      end
    end
    @constellation = ActiveFacts::API::Constellation.new(Mod)
  end

  describe "Vocabulary" do
    it "should create the constellation" do
      Mod.constellation.should be_is_a ActiveFacts::API::Constellation
    end

    it "should create the constellation by direct populate" do
      Mod.populate do
        Name "foo"
      end.should be_is_a ActiveFacts::API::Constellation
    end

    it "should verbalise" do
      s = Mod.verbalise
      s.should be_is_a String
    end
  end

  it "should allow creating a constellation" do
    @constellation = ActiveFacts::API::Constellation.new(Mod)
  end

  it "should complain when accessing a non-class as a method" do
    Mod::Foo = 23
    lambda { @constellation.Foo }.should raise_error
  end

  it "should complain when accessing a class that isn't an object type" do
    class Mod::Bar; end
    lambda { @constellation.Bar }.should raise_error
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

  it "should support methods to construct instances of any object_type" do
    name = foo = acme = fred_fly = nil
    lambda {
        name = @constellation.Name("foo")
        foo = @constellation.LegalEntity("foo")
        acme = @constellation.Company("Acme, Inc")
        fred_fly = @constellation.Person("fred", "fly")
      }.should_not raise_error
    name.class.should == Mod::Name
    name.constellation.should == @constellation
    foo.class.should == Mod::LegalEntity
    foo.constellation.should == @constellation
    acme.class.should == Mod::Company
    acme.constellation.should == @constellation
    fred_fly.class.should == Mod::Person
    fred_fly.constellation.should == @constellation
  end

  it "should re-use instances constructed the same way" do
    name1 = @constellation.Name("foo")
    foo1 = @constellation.LegalEntity("foo")
    acme1 = @constellation.Company("Acme, Inc")
    fred_fly1 = @constellation.Person("fred", "fly")

    name2 = @constellation.Name("foo")
    foo2 = @constellation.LegalEntity("foo")
    acme2 = @constellation.Company("Acme, Inc")
    fred_fly2 = @constellation.Person("fred", "fly")

    name1.object_id.should == name2.object_id
    foo1.object_id.should == foo2.object_id
    acme1.object_id.should == acme2.object_id
    fred_fly1.object_id.should == fred_fly2.object_id
  end

  it "should support population blocks" do
    @constellation.populate do
      Name("bar")
      LegalEntity("foo")
      Person("Fred", "Nerk", :auto_counter_value => :new)
      Company("Acme, Inc", :auto_counter_value => :new)
    end
    @constellation.Name.size.should == 5
    @constellation.SurrogateId.size.should == 2
  end

  it "should verbalise itself" do
    @constellation.populate do
      Name("bar")
      LegalEntity("foo")
      c = Company("Acme, Inc", :auto_counter_value => :new)
      Person("Fred", "Nerk", :auto_counter_value => :new, :employer => c)
    end
    s = @constellation.verbalise
    names = s.split(/\n/).grep(/\tEvery /).map{|l| l.sub(/.*Every (.*):$/, '\1')}
    expected = ["Company", "LegalEntity", "Name", "Person", "StringValue", "SurrogateId"]
    names.sort.should == expected
  end

  it "should support string capitalisation functions" do
    names = ["Company", "LegalEntity", "Name", "Person", "StringValue", "SurrogateId"]
    camelwords = names.map{|n| n.camelwords }
    camelwords.should == [["Company"], ["Legal", "Entity"], ["Name"], ["Person"], ["String", "Value"], ["Surrogate", "Id"]]

    snakes = names.map{|n| n.snakecase }
    snakes.should == ["company", "legal_entity", "name", "person", "string_value", "surrogate_id"]

    camelupper = snakes.map{|n| n.camelcase }
    camelupper.should == ["Company", "LegalEntity", "Name", "Person", "StringValue", "SurrogateId"]

    camellower = snakes.map{|n| n.camelcase(:lower) }
    camellower.should == ["company", "legalEntity", "name", "person", "stringValue", "surrogateId"]
  end

  it "should index value instances, including by its superclasses" do
    baz = @constellation.Name("baz")
    @constellation.Name.keys.sort.should == ["baz"]

    @constellation.StringValue.keys.sort.should == ["baz"]
  end

  describe "instance indices" do
    it "should support each" do
      baz = @constellation.Name("baz")
      count = 0
      @constellation.Name.each { |rv| count += 1 }
      count.should == 1
    end

    it "should support detect" do
      baz = @constellation.Name("baz")
      @constellation.Name.detect { |rv| true }.should be_true
    end
  end

  it "should index entity instances, including by its superclass and secondary supertypes" do
    name = "Acme, Inc"
    fred = "Fred"
    fly = "Fly"
    acme = @constellation.Company name, :auto_counter_value => :new
    fred_fly = @constellation.Person fred, fly, :auto_counter_value => :new

    # REVISIT: This should be illegal:
    #fred_fly.auto_counter_value = :new

    @constellation.Person.keys.sort.should == [[fred, fly]]
    @constellation.Company.keys.sort.should == [[name]]

    @constellation.LegalEntity.keys.sort.should be_include([name])
    @constellation.LegalEntity.keys.sort.should be_include([fred])

    @constellation.SurrogateId.values.should be_include(acme)
    @constellation.SurrogateId.values.should be_include(fred_fly)
  end

  it "should allow retraction of instances, propagating nullification or retraction" do
    person = @constellation.Person "Fred", "Smith", :auto_counter_value => :new

    @constellation.retract(@constellation.Name("Smith"))
    @constellation.Name["Smith"].should be_nil
    @constellation.Name["Fred"].should_not be_nil

    person.family_name.should be_nil
    @constellation.retract(@constellation.Name("Fred"))
    @constellation.Name["Fred"].should be_nil
    pending "Retraction of identifiers doesn't de/re-index" do
      @constellation.Person.size.should == 0
    end
  end

  it "should fail to recognise references to unresolved forward referenced classes" do
    module Mod2
      class Foo
        identified_by :name
        one_to_one :name
        has_one :bar
        has_one :baz, :class => "BAZ"
      end

      class Name < String
        value_type
      end
    end

    @c = ActiveFacts::API::Constellation.new(Mod2)
    le = @c.Foo("Foo")
    lambda {
      le.bar
    }.should raise_error(NoMethodError)
    lambda {
      le.baz
    }.should raise_error(NoMethodError)

    # Now define the classes and try again:
    module Mod2
      class Bar < String
        value_type
      end
      class BAZ < String
        value_type
      end
    end
    lambda {
      le.bar
      le.bar = 'bar'
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
        class IntValue
          has_one :thingummy, :class => Outside::Other
        end
      end
    }.should raise_error
  end

end
