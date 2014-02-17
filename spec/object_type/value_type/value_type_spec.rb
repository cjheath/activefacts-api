#
# ActiveFacts tests: Value types in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "Value Type class definitions" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      class Name < String
        value_type
        has_one :name
      end
      class Year < Int
        value_type
        has_one :name
      end
      class Weight < Real
        value_type
        has_one :name
      end
      class GivenName < Name
      end
    end

    @classes = [Mod::Name, Mod::GivenName, Mod::Year, Mod::Weight]
    @attrs = [:name, :name, :name, :name]

  end

  it "should respond_to verbalise" do
    @classes.each { |klass|
        klass.respond_to?(:verbalise).should be_true
      }
  end

  it "should not pollute the value class" do
    @classes.each { |klass|
	if !@classes.include?(klass.superclass)
	  klass.superclass.respond_to?(:verbalise).should_not be_true
	end
      }
  end

  it "should return a string from verbalise" do
    @classes.each { |klass|
        v = klass.verbalise
        v.should_not be_nil
        v.should_not =~ /REVISIT/
      }
  end

  it "should respond_to vocabulary" do
    @classes.each { |klass|
        klass.respond_to?(:vocabulary).should be_true
      }
  end

  it "should return the parent module as the vocabulary" do
    @classes.each { |klass|
        vocabulary = klass.vocabulary
        vocabulary.should == Mod
      }
  end

  it "should return a vocabulary that knows about this object_type" do
    @classes.each { |klass|
        vocabulary = klass.vocabulary
        vocabulary.respond_to?(:object_type).should be_true
        vocabulary.object_type.has_key?(klass.basename).should be_true
      }
  end

  it "should respond to roles()" do
    @classes.each { |klass|
        klass.respond_to?(:roles).should be_true
      }
  end

  it "should contain only the added role definitions" do
    @classes.each { |klass|
	num_roles = klass.roles.size
	if klass == Mod::GivenName
	  num_roles.should == 1
	elsif klass == Mod::Name
	  num_roles.should == 5
	else
	  num_roles.should == 1
	end
      }
  end

  it "should return the role definition" do
    # Check the role definition may not be accessed by passing an index:
    Mod::Name.roles(0).should be_nil

    @classes.zip(@attrs).each { |klass, attr|
        klass.roles(attr).should_not be_nil
        klass.roles(attr.to_s).should_not be_nil
        # Check the role definition may be accessed by indexing the returned array:
	unless @classes.include?(klass.superclass)
	  klass.roles(attr).should_not be_nil
	  # Check the role definition array by .include?
	  klass.roles.include?(attr).should be_true
	end
      }
  end

  # REVISIT: role value constraints

  it "should fail on a non-ValueClass" do
    lambda{
      class NameNotString
        value_type
      end
    }.should raise_error(NameError)
  end

  it "should allow configuration of Role value through constructor using role name" do
    c = ActiveFacts::API::Constellation.new(Mod)
    w = c.Weight(9.0, :name => "pounds")
    w.name.should == "pounds"
  end
end
