#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

require_relative '../fixtures/tax'
include ActiveFacts::API

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
      @eyeballs = "Eyeballs"
      @tax_return_year = @r1.year
      @r1.reviewer = @eyeballs
      @reviewer = @r1.reviewer

      @c1.AustralianTaxReturn.keys.should == [[[123], [2010]]]
      @c1.AustralianTaxReturn.values.should == [@r1]

      @c1.Name.keys.should =~ [@eyeballs, @juliar, @tony]
      @c1.Name.values.should =~ [@eyeballs, @juliar, @tony]
      @c1.Person.keys.should =~ [[@eyeballs], [@juliar], [@tony]]
      @c1.Person.values.should =~ [@reviewer, @p1, @p3]
      @c1.Australian.keys.should =~ [[@juliar], [@tony]]
      @c1.Australian.values.should =~ [@p1, @p3]
      @c1.AustralianTaxPayer.keys.should =~ [[123]]
      @c1.AustralianTaxPayer.values.should =~ [@p3]
      @c1.TFN.keys.should =~ [123]
      @reviewer.all_australian_tax_return_as_reviewer.size.should == 1
      @reviewer.all_australian_tax_return_as_reviewer.keys[0].should == [[123], [2010]]
    end

    describe "that implies change of subtype" do
      before :each do
        @p2 = nil
        @change = proc {
          @p2 = @c1.AustralianTaxPayer(:tfn => 789, :name => "Juliar Gillard")
        }
      end

      it "should be denied" do
        @change.should raise_error(TypeMigrationException)
      end

      it "should not change instance subtype" do
        @p1.class.should == Tax::Australian
      end

      it "should have no side-effects" do
        begin
          @change.call
        rescue TypeMigrationException => e
          # Now check that no unexpected change occurred
        end

        @p2.should be_nil
        @c1.Name.values.should =~ [@eyeballs, @juliar, @tony]
        @c1.Name.keys.should =~ [@eyeballs, @juliar, @tony]
        @c1.TFN.keys.should =~ [123]
        @c1.Person.values.should =~ [@reviewer, @p1, @p3]
        @c1.Person.keys.should =~ [[@eyeballs], [@juliar], [@tony]]
        @c1.Australian.values.should =~ [@p1, @p3]
      end

      it "should have no side-effects (retracting values which shouldn't)" do
        @p2_tfn = @c1.TFN(789)
        begin
          @change.call
        rescue TypeMigrationException => e
        end

        @c1.TFN.keys.should =~ [123, 789]
      end
    end

    describe "causing conflict" do
      it "should fail and make no change" do
        proc {
          @p3.name = "Juliar Gillard"    # Must fail; must leave @p3 untouched.
        }.should raise_error(ActiveFacts::API::DuplicateIdentifyingValueException)

        @p3.name.should == @tony
      end
    end

    describe "without conflict" do
      before :each do
        # Changing the TFN changes the identity of the AustralianTaxpayer,
        # and hence of any AustralianTaxReturns,
        # and the indexing for the return by a reviewer.
        @p3.tfn = 456
      end

      it "should be allowed" do
        @p3.identifying_role_values.should == [456]
      end

      it "should propagate key change to roles played" do
        @reviewer.all_australian_tax_return_as_reviewer.keys[0].should == [[456], [2010]]
        @tax_return_year.all_australian_tax_return.keys[0].should == [[456]]
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
