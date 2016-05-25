#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "An Entity Type" do
  before :all do
    module ModIS
      class Name < String
        value_type
      end

      class Number < Int
        value_type
      end
    end
  end
  before :each do
    @c = ActiveFacts::API::Constellation.new(ModIS)
  end

  describe "whose instances are identified by a single value role" do
    before :all do
      module ModIS
        class Business
          identified_by :name
          one_to_one :name
        end
      end
    end

    it "should fail if the role isn't one-to-one" do
      proc do
        module ModIS
          class Cat
            identified_by :name
            has_one :name
          end
        end
      end.should raise_error(ActiveFacts::API::InvalidIdentificationException)
    end

    describe "when asserted" do
      before :each do
        @bus = @c.Business
        @bus = @c.Business('Acme')
        @acme = @c.Name['Acme']
      end

      it "should return a new instance if not previously present" do
        @bus.should be_a(ModIS::Business)
      end

      it "should assert the identifying value" do
        @acme.should be_a(ModIS::Name)
      end

      it "should be found in the constellation using the value" do
        @c.Business[['Acme']].should == @bus
        @c.Business[[@acme]].should == @bus
      end

      it "should belong to the constellation" do
        @bus.constellation.should == @c
      end

      it "should be assigned to the value's counterpart role" do
        @acme.business.should == @bus
      end

      it "should return a previously-existing instance" do
        @c.Business[['Acme']].should == @bus
        @c.Business.size.should == 1
      end
    end

    describe "when the value is changed" do
      before :each do
        @fly = @c.Business('Fly')
        @bus = @c.Business('Acme')
        @acme = @c.Name['Acme']
      end

      it "should fail if the new value already exists" do
        proc do
          @fly.name = 'Acme'
        end.should raise_error(ActiveFacts::API::DuplicateIdentifyingValueException)
      end

      it "should not fail if the new value is self" do
        lambda { @bus.name = 'Acme' }.should_not raise_error
      end

      describe "to a previously-nonexistent value" do
        before :each do
          @bus.name = 'Bloggs'
        end

        it "should assert the new identifier" do
          @c.Name['Bloggs'].should be_a(ModIS::Name)
        end

        it "should allow the change" do
          @bus.name.should == 'Bloggs'
          @c.Business.size.should == 2
        end

        it "should be found under the new identifier" do
          @c.Business[['Bloggs']].should == @bus
        end

        it "should be in the constellation's index under the new identifier" do
          @c.Business.keys.should include ['Bloggs']
        end

        it "should be the counterpart of the new identifier" do
          @c.Name['Bloggs'].business.should == @bus
        end

        it "should not be found in the constellation using the old value" do
          @c.Business[['Acme']].should be_nil
        end

        it "the old value's back-reference is set to nil" do
          @acme.business.should be_nil
        end

        #describe "and the old identifying value plays no other roles" do
        #  describe "and the player of the identifying role is not independent" do
        #    it "should retract the previous value" do
        #      pending "All value types default to independent" do
        #        @c.Name['Acme'].should be_nil
        #      end
        #    end
        #  end
        #end

      end
    end

    describe "when retracted" do
      before :each do
        @bus = @c.Business('Acme')
        @acme = @c.Name['Acme']
      end

      it "should disappear from the constellation" do
        @bus.retract
        @c.Business[['Acme']].should be_nil
      end

      describe "and the identifying value plays no other roles" do
        describe "and the player of the identifying role is not independent" do
          before :each do
            @bus.retract
          end

          #it "should retract the identifying value also" do
          #  pending "All value types default to independent" do
          #    @c.Name['Acme'].should be_nil
          #  end
          #end

          it "should not appear as the value's counterpart role" do
            @acme.business.should be_nil
          end
        end

        describe "and the identifying value plays other roles" do
          before :all do
            module ModIS
              class Dog
                identified_by :name
                one_to_one :name
              end
            end
          end
          before :each do
            @c.Dog("Acme")
            @bus.retract
          end

          it "should retain the identifying value, but with a nil counterpart role" do
            @c.Name['Acme'].should == @acme
            @acme.business.should be_nil
          end
        end
      end
    end
  end

  describe "identified by two values" do
    before :all do
      module ModIS
        class Building
          identified_by :name
          one_to_one :name
        end

        class Room
          identified_by :building, :number
          has_one :building
          has_one :number
        end

        class OwnershipId < Int
          value_type
        end

        class Owner
          identified_by :ownership_id, :building
          has_one :ownership_id
          has_one :building
        end

        class OwnerRoom
          identified_by :owner, :room
          has_one :owner
          has_one :room
        end
      end
    end

    before :each do
      @c = ActiveFacts::API::Constellation.new(ModIS)
    end

    it "should fail if any role is one-to-one" do
      proc do
        module ModIS
          class Floor
            identified_by :building, :number
            has_one :building
            one_to_one :number    # Error, invalid identifier
          end
        end
      end.should raise_error(ActiveFacts::API::InvalidIdentificationException)
    end

    describe "when asserted" do
      before :each do
        @b = @c.Building('Mackay')
        @mackay = @b.name
        @r = @c.Room(@b, 101)
        @rn = @r.number

        @o = @c.Owner(1_001, @b)
        @or = @c.OwnerRoom(@o, @r)
      end

      it "should return a new instance if not previously present" do
        @r.should be_a(ModIS::Room)
      end

      it "should assert the identifying values" do
        @rn.should be_a(ModIS::Number)
        @c.Number[@rn.identifying_role_values].should == @rn    # Yes
        @c.Number[101].should == @rn    # No
        @c.Number[101].should be_eql 101    # No
      end

      it "should be found in the constellation using the value" do
        @c.Room[[@b.identifying_role_values, @rn.identifying_role_values]].should == @r
        @c.Room[[@b.identifying_role_values, 101]].should == @r
        @c.Room[[['Mackay'], 101]].should == @r
      end

      it "should belong to the constellation" do
        @r.constellation.should == @c
      end

      it "should be added to the values' counterpart roles" do
        @rn.all_room.to_a.should == [@r]
        @b.all_room.to_a.should == [@r]
      end

      it "should return a previously-existing instance" do
        @c.Room(@b, 101).should == @r
        @c.Room(['Mackay'], 101).should == @r
        @c.Room.size.should == 1
      end
    end

    describe "when the value is changed" do
      before :each do
        @b = @c.Building('Mackay')
        @mackay = @c.Name['Mackay']
        @r = @c.Room(@b, 101)
        @rn = @r.number

        @o = @c.Owner(1_001, @b)
        @or = @c.OwnerRoom(@o, @r)
      end

      it "should fail if the new value already exists" do
        @c.Room(@b, 102)
        lambda { @r.number = 102 }.should raise_error(ActiveFacts::API::DuplicateIdentifyingValueException)
      end

      describe "to a previously-nonexistent value" do
        before :each do
          @r.number = 103
          @new_number = @r.number
        end

        it "should assert the new identifier" do
          @new_number.should_not be_nil
        end

        it "should allow the change" do
          @r.number.should == @new_number
          @r.number.should be_eql(103)

          # Check that counterpart role value lists have been updated:
          @b.all_room.keys[0].should == [103]
          @o.all_owner_room.keys[0].should == [[["Mackay"], 103]]
        end

        it "should be found under the new identifier" do
          @c.Room[[@b.identifying_role_values, 103]].should == @r
          @c.Room[[['Mackay'], 101]].should be_nil
        end

        it "should be found under the new identifier even on deep associations" do
#          p @c.OwnerRoom.keys[0]
#          p @new_number
#          p [@o.identifying_role_values, @r.identifying_role_values]
          @c.OwnerRoom[[@o.identifying_role_values, @r.identifying_role_values]].should == @or
          @c.OwnerRoom[[[1_001, ['Mackay']], [['Mackay'], 103]]].should == @or
          @c.OwnerRoom[[[1_001, ['Mackay']], [['Mackay'], 101]]].should be_nil
        end

        it "should be in the constellation's index under the new identifier" do
          @c.Room(['Mackay'], @r.number).should_not be_nil
        end

        it "should be included in the counterparts of the new identifier roles" do
          @b.all_room.to_a.should == [@r]
          @new_number.all_room.to_a.should == [@r]
        end

        it "should not be found in the constellation using the old value" do
          @c.Room.keys[0].should_not == [['Mackay'],101]
        end

        it "the old value's back-reference is set to nil" do
          # @rn.all_room.should_not include @r
          @rn.all_room.to_a.should_not include @r
        end

        #describe "and the old identifying value plays no other roles" do
        #  describe "and the player of the identifying role is not independent" do
        #    it "should retract the previous value" do
        #      pending "All value types default to independent" do
        #        @c.Number[101].should be_nil
        #      end
        #    end
        #  end
        #end
      end
    end

=begin
    describe "when retracted" do
      it "should disappear from the constellation"
      describe "and the identifying value plays no other roles" do
        describe "and the player of the identifying role is not independent" do
          it "should retract the identifying value also"
          it "should not appear as the value's counterpart role"
        end
        describe "and the identifying value plays other roles" do
          it "should retain the identifying value, but with a nil counterpart role"
        end
      end
    end
=end

  end

=begin
  describe "which inherits its identification from a supertype" do
    describe "which also has a secondary supertype" do
    end
  end

  describe "which has a supertype that has separate identification" do
    before :each do
      module ModIS
        class Animal
          identified_by :number
          one_to_one :neumber
        end
        class Dog < Animal
          identified_by :name
          one_to_one :name
        end
      end
    end

    describe "when asserted" do
      describe "and both identifiers are new" do
        it "should be found using the respective identifiers"
      end
      describe "and only the supertype identifier is new" do
        it "should be rejected because of the duplicate subtype identifier"
      end
      describe "and only the subtype identifier is new" do
        it "should be rejected because of the duplicate supertype identifier"
      end
    end

    describe "when the subtype identifier is changed" do
      it "should fail if the new subtype value already exists"
      it "should allow the change if the new subtype value doesn't already exist"
    end

    describe "when the supertype identifier is changed" do
      it "should fail if the new supertype value already exists"
      it "should allow the change if the new supertype value doesn't already exist"
    end

  end
=end
end
