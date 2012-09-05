#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe ActiveFacts::API::InstanceIndex do
  before :all do
    module Mod
      class ValueA < Int
        value_type
      end

      class ValueB < String
        value_type
      end

      class EntityA
        identified_by :value_a
        one_to_one :value_a
        has_one :value_b
      end

      class EntityB < EntityA
        identified_by :value_b
        one_to_one :value_b
      end

      class EntityD < EntityA
      end

      class EntityC < EntityB
        supertypes EntityD
      end
    end

    @constellation = ActiveFacts::API::Constellation.new(Mod)
    @a = @constellation.EntityA(:value_a => 1, :value_b => 'a')
    @b = @constellation.EntityB(:value_a => 12, :value_b => 'ab')
    @c = @constellation.EntityC(:value_a => 123, :value_b => 'abc')
  end

  it "should index its own class" do
    @constellation.instances[Mod::EntityC].size.should == 1
  end

  it "should index instances of subtypes" do
    @constellation.instances[Mod::EntityA].size.should == 3
    @constellation.instances[Mod::EntityB].size.should == 2
    @constellation.instances[Mod::EntityD].size.should == 1
  end

  describe "#flatten_key" do
    it "should use identifying role values when using an entity type" do
      @constellation.EntityA[@a].should == @a
    end

    it "should recursively try to use identifying role values within an array" do
      value_b = @constellation.ValueB('abc')
      @constellation.EntityC[[value_b]].should == @c
    end

    it "should use the value as-is if it doesn't have identifying role values" do
      @constellation.EntityC[%w{abc}].should == @c
    end
  end

  describe 'Enumerable implementation' do
    it 'should have an arity of 1 for #each' do
      @constellation.EntityA.each do |*args|
        args.size.should == 1
      end
    end
  end
end