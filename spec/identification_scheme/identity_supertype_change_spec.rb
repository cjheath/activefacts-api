#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe 'identity change on subtype' do
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

    @constellation = ActiveFacts::API::Constellation.new(Mod)
    @a = @constellation.EntityA(123)
  end

  it "should fail if the value is the same" do
    lambda { @b = @constellation.EntityB(123, 'abc') }.should raise_error(ActiveFacts::API::UnexpectedIdentifyingValueException)
  end

  context "on a deep-subtype" do
    before :all do
      module Mod
        class EntityC < EntityB
        end
      end

      @c = @constellation.EntityC(:value_a => 1, :value_b => 'abc')
    end

    it "should fail if the value already exist" do
      @a.value_a.should == 123
      @c.value_a.should == 1
      lambda { @a.value_a = 1 }.should raise_error(ActiveFacts::API::DuplicateIdentifyingValueException)
      lambda { @c.value_a = 123 }.should raise_error(ActiveFacts::API::DuplicateIdentifyingValueException)
    end

    it "should keep the previous value intact" do
      @a.value_a.should == 123
      @c.value_a.should == 1
    end

    it "should allow the change when the value doesn't exist" do
      @c.value_a = 987
      @c.value_a.should == 987
      @c.value_b.all_entitya.keys[0].should == [987]
    end
  end
end
