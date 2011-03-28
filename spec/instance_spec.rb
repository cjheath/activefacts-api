#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'rspec'
require 'activefacts/api'

describe "An instance of every type of ObjectType" do
  before :each do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      # These are the base value types we're going to test:
      @base_types = [
          Int, Real, AutoCounter, String, Date, DateTime, Decimal
        ]

      # Construct the names of the roles they play:
      @base_type_roles = @base_types.map do |t|
        t.name.snakecase
      end
      @role_names = @base_type_roles.inject([]) {|a, t|
          a << :"#{t}_value"
        } +
        @base_type_roles.inject([]) {|a, t|
          a << :"#{t}_sub_value"
        }

      # Create a value type and a subtype of that value type for each base type:
      @base_types.each do |base_type|
        eval <<-END
          class #{base_type.name}Value < #{base_type.name}
            value_type
          end

          class #{base_type.name}SubValue < #{base_type.name}Value
            # Note no new "value_type" is required here, it comes through inheritance
          end
        END
      end

      # Create a TestByX, TestByXSub, and TestSubByX class for all base types X
      # Each class has a has_one and a one_to_one for all roles.
      # and is identified by the has_one :x role
      @base_types.each do |base_type|
        code = <<-END
          class TestBy#{base_type.name}
            identified_by :#{base_type.name.snakecase}_value#{
              @role_names.map do |role_name|
                %Q{
            has_one :#{role_name}#{
              mandatory = (role_name == (base_type.name.snakecase+'_value').to_sym ? ', :mandatory => true' : '')
            }
            one_to_one :one_#{role_name}, :class => #{role_name.to_s.camelcase}}
              end*""
            }
          end

          class TestBy#{base_type.name}Sub
            identified_by :#{base_type.name.snakecase}_sub_value#{
              @role_names.map do |role_name|
                %Q{
            has_one :#{role_name}
            one_to_one :one_#{role_name}, :class => #{role_name.to_s.camelcase}}
              end*""
            }
          end

          class TestSubBy#{base_type.name} < TestBy#{base_type.name}
            # Entity subtypes, inherit identification and all roles
          end

          class TestBy#{base_type.name}Entity
            identified_by :test_by_#{base_type.name.snakecase}
            one_to_one :test_by_#{base_type.name.snakecase}
          end
        END
        eval code
      end
    end

    # Simple Values
    @int = 0
    @real = 0.0
    @auto_counter = 0
    @new_auto_counter = :new
    @string = "zero"
    @date = [2008, 04, 19]
    @date_time = [2008, 04, 19, 10, 28, 14]
    @decimal = BigDecimal.new('98765432109876543210')

    # Value Type instances
    @int_value = Mod::IntValue.new(1)
    @real_value = Mod::RealValue.new(1.0)
    @auto_counter_value = Mod::AutoCounterValue.new(1)
    @new_auto_counter_value = Mod::AutoCounterValue.new(:new)
    @string_value = Mod::StringValue.new("one")
    @date_value = Mod::DateValue.new(2008, 04, 20)
    # Parse the date:
    @date_value = Mod::DateValue.new '2nd Nov 2001'
    d = ::Date.civil(2008, 04, 20)
    @date_time_value = Mod::DateTimeValue.new d # 2008, 04, 20, 10, 28, 14
    # This next isn't in the same pattern; it makes a Decimal from a BigDecimal rather than a String (coverage reasons)
    @decimal_value = Mod::DecimalValue.new(BigDecimal.new('98765432109876543210'))

    # Value SubType instances
    @int_sub_value = Mod::IntSubValue.new(4)
    @real_sub_value = Mod::RealSubValue.new(4.0)
    @auto_counter_sub_value = Mod::AutoCounterSubValue.new(4)
    @auto_counter_sub_value_new = Mod::AutoCounterSubValue.new(:new)
    @string_sub_value = Mod::StringSubValue.new("five")
    @date_sub_value = Mod::DateSubValue.new(2008, 04, 25)
    @date_time_sub_value = Mod::DateTimeSubValue.new(::DateTime.civil(2008, 04, 26, 10, 28, 14))
    # This next isn't in the same pattern; it makes a Decimal from a BigNum rather than a String (coverage reasons)
    @decimal_sub_value = Mod::DecimalSubValue.new(98765432109876543210)

    # Entities identified by Value Type, SubType and Entity-by-value-type instances
    @test_by_int = Mod::TestByInt.new(2)
    @test_by_real = Mod::TestByReal.new(2.0)
    @test_by_auto_counter = Mod::TestByAutoCounter.new(2)
    @test_by_auto_counter_new = Mod::TestByAutoCounter.new(:new)
    @test_by_string = Mod::TestByString.new("two")
    @test_by_date = Mod::TestByDate.new(Date.new(2008,04,28))
    #@test_by_date = Mod::TestByDate.new(2008,04,28)
    # Pass an array of values directly to DateTime.civil:
    @test_by_date_time = Mod::TestByDateTime.new([[2008,04,28,10,28,15]])
    #@test_by_date_time = Mod::TestByDateTime.new(DateTime.new(2008,04,28,10,28,15))
    @test_by_decimal = Mod::TestByDecimal.new('98765432109876543210')

    @test_by_int_sub = Mod::TestByIntSub.new(2)
    @test_by_real_sub = Mod::TestByRealSub.new(5.0)
    @test_by_auto_counter_sub = Mod::TestByAutoCounterSub.new(6)
    @test_by_auto_counter_new_sub = Mod::TestByAutoCounterSub.new(:new)
    @test_by_string_sub = Mod::TestByStringSub.new("six")
    @test_by_date_sub = Mod::TestByDateSub.new(Date.new(2008,04,27))
    @test_by_date_time_sub = Mod::TestByDateTimeSub.new(2008,04,29,10,28,15)
    @test_by_decimal_sub = Mod::TestByDecimalSub.new('98765432109876543210')

    @test_by_int_entity = Mod::TestByIntEntity.new(@test_by_int)
    @test_by_real_entity = Mod::TestByRealEntity.new(@test_by_real)
    @test_by_auto_counter_entity = Mod::TestByAutoCounterEntity.new(@test_by_auto_counter)
    @test_by_auto_counter_new_entity = Mod::TestByAutoCounterEntity.new(@test_by_auto_counter_new)
    @test_by_string_entity = Mod::TestByStringEntity.new(@test_by_string)
    @test_by_date_entity = Mod::TestByDateEntity.new(@test_by_date)
    @test_by_date_time_entity = Mod::TestByDateTimeEntity.new(@test_by_date_time)
    @test_by_decimal_entity = Mod::TestByDecimalEntity.new(@test_by_decimal)

    # Entity subtypes
    @test_sub_by_int = Mod::TestSubByInt.new(2)
    @test_sub_by_real = Mod::TestSubByReal.new(2.0)
    @test_sub_by_auto_counter = Mod::TestSubByAutoCounter.new(2)
    @test_sub_by_auto_counter_new = Mod::TestSubByAutoCounter.new(:new)
    @test_sub_by_string = Mod::TestSubByString.new("two")
    @test_sub_by_date = Mod::TestSubByDate.new(Date.new(2008,04,28))
    @test_sub_by_date_time = Mod::TestSubByDateTime.new(2008,04,28,10,28,15)
    @test_sub_by_decimal = Mod::TestSubByDecimal.new('98765432109876543210')

    # These arrays get zipped together in various ways. Keep them aligned.
    @values = [
        @int, @real, @auto_counter, @new_auto_counter,
        @string, @date, @date_time, @decimal
      ]
    @classes = [
        Int, Real, AutoCounter, AutoCounter,
        String, Date, DateTime, Decimal
      ]
    @value_types = [
        Mod::IntValue, Mod::RealValue, Mod::AutoCounterValue, Mod::AutoCounterValue,
        Mod::StringValue, Mod::DateValue, Mod::DateTimeValue, Mod::DecimalValue,
        Mod::IntSubValue, Mod::RealSubValue, Mod::AutoCounterSubValue, Mod::AutoCounterSubValue,
        Mod::StringSubValue, Mod::DateSubValue, Mod::DateTimeSubValue, Mod::DecimalSubValue,
        ]
    @value_instances = [
        @int_value, @real_value, @auto_counter_value, @new_auto_counter_value,
        @string_value, @date_value, @date_time_value, @decimal_value,
        @int_sub_value, @real_sub_value, @auto_counter_sub_value, @auto_counter_sub_value_new,
        @string_sub_value, @date_sub_value, @date_time_sub_value, @decimal_sub_value,
        @int_value, @real_value, @auto_counter_value, @new_auto_counter_value,
        @string_value, @date_value, @date_time_value, @decimal_value,
      ]
    @entity_types = [
        Mod::TestByInt, Mod::TestByReal, Mod::TestByAutoCounter, Mod::TestByAutoCounter,
        Mod::TestByString, Mod::TestByDate, Mod::TestByDateTime, Mod::TestByDecimal,
        Mod::TestByIntSub, Mod::TestByRealSub, Mod::TestByAutoCounterSub, Mod::TestByAutoCounterSub,
        Mod::TestByStringSub, Mod::TestByDateSub, Mod::TestByDateTimeSub, Mod::TestByDecimalSub,
        Mod::TestSubByInt, Mod::TestSubByReal, Mod::TestSubByAutoCounter, Mod::TestSubByAutoCounter,
        Mod::TestSubByString, Mod::TestSubByDate, Mod::TestSubByDateTime, Mod::TestByDecimalEntity,
      ]
    @entities = [
        @test_by_int, @test_by_real, @test_by_auto_counter, @test_by_auto_counter_new,
        @test_by_string, @test_by_date, @test_by_date_time, @test_by_decimal,
        @test_by_int_sub, @test_by_real_sub, @test_by_auto_counter_sub, @test_by_auto_counter_new_sub,
        @test_by_string_sub, @test_by_date_sub, @test_by_date_time_sub, @test_by_decimal_sub,
        @test_sub_by_int, @test_sub_by_real, @test_sub_by_auto_counter, @test_sub_by_auto_counter_new,
        @test_sub_by_string, @test_sub_by_date, @test_sub_by_date_time, @test_sub_by_decimal,
      ]
    @entities_by_entity = [
        @test_by_int_entity,
        @test_by_real_entity,
        @test_by_auto_counter_entity,
        @test_by_auto_counter_new_entity,
        @test_by_string_entity,
        @test_by_date_entity,
        @test_by_date_time_entity,
        @test_by_decimal_entity,
      ]
    @entities_by_entity_types = [
        Mod::TestByIntEntity, Mod::TestByRealEntity, Mod::TestByAutoCounterEntity, Mod::TestByAutoCounterEntity,
        Mod::TestByStringEntity, Mod::TestByDateEntity, Mod::TestByDateTimeEntity, Mod::TestByDecimalEntity,
      ]
    @test_role_names = [
        :int_value, :real_value, :auto_counter_value, :auto_counter_value,
        :string_value, :date_value, :date_time_value, :decimal_value,
        :int_sub_value, :real_sub_value, :auto_counter_sub_value, :auto_counter_sub_value,
        :string_sub_value, :date_sub_value, :date_time_sub_value, :decimal_sub_value,
        :int_value, :real_value, :auto_counter_value, :auto_counter_value,
        :string_value, :date_value, :date_time_value, :decimal_value,
      ]
    @role_values = [
        3, 4.0, 5, 6,
        "three", Date.new(2008,4,21), DateTime.new(2008,4,22,10,28,16),
        '98765432109876543210'
      ]
    @role_alternate_values = [
        4, 5.0, 6, 7,
        "four", Date.new(2009,4,21), DateTime.new(2009,4,22,10,28,16),
        '98765432109876543211'
      ]
    @subtype_role_instances = [
        Mod::IntSubValue.new(6), Mod::RealSubValue.new(6.0),
        Mod::AutoCounterSubValue.new(:new), Mod::AutoCounterSubValue.new(8),
        Mod::StringSubValue.new("seven"),
        Mod::DateSubValue.new(2008,4,29), Mod::DateTimeSubValue.new(2008,4,30,10,28,16),
        Mod::DecimalSubValue.new('98765432109876543210'),
      ]
  end

  describe "verbalisation" do
    it "if a value type, should verbalise" do
      @value_types.each do |value_type|
        #puts "#{value_type} verbalises as #{value_type.verbalise}"
        value_type.respond_to?(:verbalise).should be_true
        verbalisation = value_type.verbalise
        verbalisation.should =~ %r{\b#{value_type.basename}\b}
        verbalisation.should =~ %r{\b#{value_type.superclass.basename}\b}
      end
    end

    it "if an entity type, should verbalise" do
      @entity_types.each do |entity_type|
        #puts entity_type.verbalise
        entity_type.respond_to?(:verbalise).should be_true
        verbalisation = entity_type.verbalise
        verbalisation.should =~ %r{\b#{entity_type.basename}\b}

        # All identifying roles should be in the verbalisation.
        # Strictly this should be the role name, but we don't set names here.
        entity_type.identifying_role_names.each do |ir|
            role = entity_type.roles(ir)
            role.should_not be_nil
            counterpart_object_type = role.counterpart_object_type
            verbalisation.should =~ %r{\b#{counterpart_object_type.basename}\b}
          end
      end
    end

    it "should inspect" do
      (@value_instances+@entities+@entities_by_entity).each do |object|
        object.inspect
      end
    end

    it "if a value, should verbalise" do
      @value_instances.each do |value|
        #puts value.verbalise
        value.respond_to?(:verbalise).should be_true
        verbalisation = value.verbalise
        verbalisation.should =~ %r{\b#{value.class.basename}\b}
      end
    end

    it "if an entity, should respond to verbalise" do
      (@entities+@entities_by_entity).each do |entity|
        #puts entity.verbalise
        entity.respond_to?(:verbalise).should be_true
        verbalisation = entity.verbalise
        verbalisation.should =~ %r{\b#{entity.class.basename}\b}
        entity.class.identifying_role_names.each do |ir|
            role = entity.class.roles(ir)
            role.should_not be_nil
            counterpart_object_type = role.counterpart_object_type
            verbalisation.should =~ %r{\b#{counterpart_object_type.basename}\b}
          end
      end
    end
  end

  it "should respond to constellation" do
    (@value_instances+@entities+@entities_by_entity).each do |instance|
      instance.respond_to?(:constellation).should be_true
    end
  end

  it "should return the module in response to .vocabulary()" do
    (@value_types+@entity_types).zip((@value_instances+@entities+@entities_by_entity)).each do |object_type, instance|
      instance.class.vocabulary.should == Mod
    end
  end

  it "should disallow treating an unresolved AutoCounter as an integer" do
    c = ActiveFacts::API::Constellation.new(Mod)
    a = c.AutoCounterValue(:new)
    lambda {
      b = 2 + a
    }.should raise_error
    a.assign(3)
    lambda {
      b = 2 + a
      a.to_i
    }.should_not raise_error
  end

  it "should complain when not enough identifying values are provided for an entity" do
    c = ActiveFacts::API::Constellation.new(Mod)
    lambda {
      c.TestByInt(:int_value => nil)
    }.should raise_error
  end

  it "should complain when too many identifying values are provided for an entity" do
    c = ActiveFacts::API::Constellation.new(Mod)
    lambda {
      c.TestByInt(2, 3)
    }.should raise_error
  end

  it "should handle a non-mandatory missing identifying role" do
    module Mod2
      class Word
        identified_by :singular, :plural
        has_one :singular, :class => "Spelling", :mandatory => true
        has_one :plural, :class => "Spelling"
      end
      class Spelling < String
        value_type
      end
    end
    c = ActiveFacts::API::Constellation.new(Mod2)
    s = c.Word('sheep')
    f = c.Word('fish', :plural => nil)
    a = c.Word('aircraft', nil)
    s.plural.should be_nil
    f.plural.should be_nil
    a.plural.should be_nil
  end

  it "should handle a unary as an identifying role" do
    module Mod2
      class Status
        identified_by :is_ok
        maybe :is_ok
      end
    end
    c = ActiveFacts::API::Constellation.new(Mod2)

    n = c.Status(:is_ok => nil)
    t = c.Status(:is_ok => true)
    f = c.Status(:is_ok => false)
    s = c.Status(:is_ok => 'foo')
    n.is_ok.should == nil
    t.is_ok.should == true
    f.is_ok.should == false
    s.is_ok.should == true

    n.is_ok = nil
    t.is_ok = true
    f.is_ok = false
    s.is_ok = true
    n.is_ok.should == nil
    t.is_ok.should == true
    f.is_ok.should == false
    s.is_ok.should == true
  end

end
