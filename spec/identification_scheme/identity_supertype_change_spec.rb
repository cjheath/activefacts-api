#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#


describe 'identity change on supertype' do
  before :all do
    module Mod
      class EntityA
        identified_by :value_a
        one_to_one :value_a
        has_one :value_b
      end

      class ValueA < Int
        value_type
      end

      class ValueB < String
        value_type
      end

      class EntityB < EntityA
        identified_by :value_b
      end
    end
  end

  before :each do
    @constellation = ActiveFacts::API::Constellation.new(Mod)
    @a = @constellation.EntityA(123)
  end

  context "when no subtype is defined for the identifying value" do
    it "should change the identifying value" do
      lambda { @a.value_a = 1 }.should_not raise_error
      @a.value_a.should == 1
    end
  end

  context "when there is a subtype with the same value defined" do
    before :each do
      @b = @constellation.EntityB(:value_a => 123, :value_b => 'abc')
    end

    it "should fail to change the value on the supertype entity" do
      pending "invalid operation" do
        lambda { @a.value_a = 1 }.should raise_error
      end
      @b.value_a.should == 123
    end
  end
end