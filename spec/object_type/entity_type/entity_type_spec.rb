#
# ActiveFacts tests: Entity classes in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "Entity Type class definitions" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      class Name < String
        value_type
      end
      class LegalEntity
      end
      class Person < LegalEntity
        identified_by :name
        one_to_one :name, :class => Name
      end
    end
  end

  it "should respond_to verbalise" do
    Mod::Person.respond_to?(:verbalise).should be true
  end

  it "should not pollute the superclass" do
    Mod::LegalEntity.respond_to?(:verbalise).should_not be true
    Class.respond_to?(:verbalise).should_not be true
  end

  it "should return a string from verbalise" do
    v = Mod::Person.verbalise
    v.should_not be_nil
    v.should_not =~ /REVISIT/
  end

  it "should respond_to vocabulary" do
    Mod::Person.respond_to?(:vocabulary).should be true
  end

  it "should return the parent module as the vocabulary" do
    vocabulary = Mod::Person.vocabulary
    vocabulary.should == Mod
  end

  it "should return a vocabulary that knows about this object_type" do
    vocabulary = Mod::Person.vocabulary
    vocabulary.respond_to?(:object_type).should be true
    vocabulary.object_type.has_key?("Person").should be_truthy
  end

  it "should respond to all_role()" do
    Mod::Person.respond_to?(:all_role).should be true
  end

  it "should contain only the added role definition" do
    Mod::Person.all_role.size.should == 1
  end

  it "should return the role definition" do
    # Check the role definition may be accessed by passing an index:
    Mod::Person.all_role(0).should be_nil

    role = Mod::Person.all_role(:name)
    role.should_not be_nil

    role = Mod::Person.all_role("name")
    role.should_not be_nil

    # Check the role definition may be accessed by indexing the returned hash:
    role = Mod::Person.all_role[:name]
    role.should_not be_nil

    # Check the role definition array by .include?
    Mod::Person.all_role.include?(:name).should be true
  end

  it "should fail on a ValueType" do
    lambda{
      class SomeClass < String
        identified_by :foo
      end
    }.should raise_error(ActiveFacts::API::InvalidEntityException)
  end

  it "should return the identifying roles" do
    Mod::Person.identifying_role_names.should == [:name]
  end

  it "should prevent a role name from matching a object_type that exists unless that object_type is the counterpart" do
    proc do
      module Mod
	class LegalEntity
	end
	class Bad
	  identified_by :name
	  has_one :name, :class => LegalEntity
	end
      end
    end.should raise_error(ActiveFacts::API::CrossVocabularyRoleException)
  end
end
