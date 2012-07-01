require 'activefacts/api'
require 'tax'
require 'rspec'
require 'rspec/matchers'
include ActiveFacts::API
include RSpec::Matchers

describe "identity" do
  before :each do
    @c1 = Constellation.new(Tax)
    @juliar = "Juliar Gillard"

    @p1 = @c1.Australian(@juliar)
  end

  it "should be indexed" do
    @c1.Name.keys.should == [@juliar]
    @c1.Name.values.should == [@juliar]
    @c1.Person.keys.should == [[@juliar]]
    @c1.Person.values.should == [@p1]
    @c1.Australian.keys.should == [[@juliar]]
    @c1.Australian.values.should == [@p1]
  end

  describe "change" do
    before :each do
      @tony = "Tony Abbot"
      @p3 = @c1.AustralianTaxPayer(:tfn => 123, :name => @tony)

      @r1 = @c1.AustralianTaxReturn(@p3, 2010)
      @c1.AustralianTaxReturn.keys.should == [[[123], [2010]]]
      @c1.AustralianTaxReturn.values.should == [@r1]

      @c1.Name.keys.should =~ [@juliar, @tony]
      @c1.Name.values.should =~ [@juliar, @tony]
      @c1.Person.keys.should =~ [[@juliar], [@tony]]
      @c1.Person.values.should =~ [@p1, @p3]
      @c1.Australian.keys.should =~ [[@juliar], [@tony]]
      @c1.Australian.values.should =~ [@p1, @p3]
      @c1.AustralianTaxPayer.keys.should =~ [[123]]
      @c1.AustralianTaxPayer.values.should =~ [@p3]
    end

    describe "that implies change of subtype" do
      before :each do
        @p2 = nil
        @change = proc {
          @p2 = @c1.AustralianTaxPayer(:tfn => 789, :name => "Juliar Gillard")
          # Must fail; must not create TFN=789; must not change Juliar into an AustralianTaxPayer
        }
      end

      it "should be denied" do
        @change.should raise_error(ImplicitSubtypeChangeDisallowedException)
      end

      it "should not change instance subtype" do
        @p1.class.should == Tax::Australian
      end

      it "should have no side-effects" do
        begin
          @change.call
        rescue ImplicitSubtypeChangeDisallowedException => e
        end

        @p2.should be_nil
        @c1.Name.values.should =~ [@juliar, @tony]
        @c1.Name.keys.should =~ [@juliar, @tony]
        @c1.TFN.keys.should =~ [123]
        @c1.Person.values.should =~ [@p1, @p3]
        @c1.Person.keys.should =~ [[@juliar],[@tony]]
        @c1.Australian.values.should =~ [@p1, @p3]
      end

      it "should have no side-effects (retracting values which shouldn't)" do
        @p2_tfn = @c1.TFN(789)
        begin
          @change.call
        rescue ImplicitSubtypeChangeDisallowedException => e
        end

        @c1.TFN.keys.should =~ [123, 789]
      end
    end

    describe "causing conflict" do
      it "should fail and make no change" do
        proc {
          @p3.name = "Juliar Gillard"    # Must fail; must leave @p3 untouched.
        }.should raise_error # (ActiveFacts::API::AmbiguousIdentityChange)

        @p3.name.should == @tony
      end
    end

    describe "without conflict" do
      before :each do
        @p3.tfn = 456
      end

      it "should be allowed" do
        @p3.identifying_role_values.should == [456]
      end

      it "should be re-indexed" do
        @c1.AustralianTaxPayer.keys.should == [[456]]
      end

      it "should be propagated" do
        key = [[456], [2010]]
        @r1.identifying_role_values.should == key
        @c1.AustralianTaxReturn.keys.should == [key]
        @c1.AustralianTaxReturn.values.should == [@r1]
      end
    end
  end
end
