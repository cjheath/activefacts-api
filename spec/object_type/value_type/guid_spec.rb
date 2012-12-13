#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "Guid Value Type instances" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      class ThingId < Guid
        value_type
      end
      class Thing
        identified_by :thing_id
        one_to_one :thing_id
      end
      class Ordinal < Int
        value_type
      end
      class ThingFacet
        identified_by :thing, :ordinal
        has_one :thing
        has_one :ordinal
      end
    end
    @constellation = ActiveFacts::API::Constellation.new(Mod)
    @thing = @constellation.Thing(:new)
    @thing_id = @constellation.ThingId(:new)
  end

  it "should respond to verbalise" do
    @thing_id.respond_to?(:verbalise).should be_true
  end

  it "should verbalise correctly" do
    @thing_id.verbalise.should =~ /ThingId '[-0-9a-f]{36}'/i
  end

  it "should respond to constellation" do
    @thing_id.respond_to?(:constellation).should be_true
  end

  it "should respond to its roles" do
    @thing_id.respond_to?(:thing).should be_true
  end

  it "should allow prevent invalid role assignment" do
    lambda {
        @thing.thing_id = "foo"
      }.should raise_error
  end

  it "should allow an existing guid to be re-used" do
    @new_thing = @constellation.Thing(@thing_id)
    @new_thing.thing_id.should == @thing_id
  end

  it "should return the ValueType in response to .class()" do
    @thing_id.class.vocabulary.should == Mod
  end

  it "should allow an existing guid-identified object to be re-used" do
    thing = @constellation.Thing(:new)
    facets = []
    facets << @constellation.ThingFacet(thing, 0)
    facets << @constellation.ThingFacet(thing, 1)
    facets[0].thing.should be_eql(facets[1].thing)
    facets[0].thing.thing_id.should be_eql(facets[1].thing.thing_id)
  end

end
