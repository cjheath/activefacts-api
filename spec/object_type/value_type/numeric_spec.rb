#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe Int do
  before :each do
    @i = Int.new(1)
  end

  it "should be encodable in JSON" do
    @i.to_json.should == "1"
  end

  it "should behave like an Integer" do
    1.should == @i
    @i.should == 1
    @i.to_s.should == "1"
    @i.should eql 1
    @i.should be_an Integer
  end

  it "should also know that it's a delegator" do
    @i.is_a?(SimpleDelegator).should be_true
    @i.is_a?(Int).should be_true
  end
end

describe Real do
  before :each do
    @r = Real.new(1.0)
  end

  it "should be encodable in JSON" do
    @r.to_json.should == "1.0"
  end

  it "should behave like a Float" do
    1.0.should == @r
    @r.should == 1.0
    @r.to_s.should == "1.0"
    @r.eql?(1.0).should be_true
    @r.is_a?(Float).should be_true
  end

  it "should also know that it's a delegator" do
    @r.is_a?(SimpleDelegator).should be_true
    @r.is_a?(Real).should be_true
  end
end

describe Decimal do
  it "should still detect Decimal as the main class" do
    bd = Decimal.new("98765432109876543210")
    bd.should be_a Decimal
    bd.should be_a BigDecimal
  end
end
