#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

describe "An instance of every type of ObjectType" do
  before :all do
    Object.send :remove_const, :Mod if Object.const_defined?("Mod")
    module Mod
      # These are the base value types we're going to test:
      @base_types = [
          Int, Real, AutoCounter, String, Date, DateTime, Decimal, Guid
        ]

      # Construct the names of the roles they play:
      @base_type_roles = @base_types.map do |t|
        t.name.snakecase
      end
      @role_names = @base_type_roles.inject([]) {|a, t|
          a << :"#{t}_val"
        } +
        @base_type_roles.inject([]) {|a, t|
          a << :"#{t}_sub_val"
        }

      # Create a value type and a subtype of that value type for each base type:
      @base_types.each do |base_type|
        Mod.module_eval <<-END
          class #{base_type.name}Val < #{base_type.name}
            value_type
          end

          class #{base_type.name}SubVal < #{base_type.name}Val
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
            identified_by :#{base_type.name.snakecase}_val#{
              @role_names.map do |role_name|
                %Q{
            #{
              (role_name == (base_type.name.snakecase+'_val').to_sym ? "one_to_one :#{role_name}, :mandatory => true" : "has_one :#{role_name}")
            }
            one_to_one :one_#{role_name}, :class => #{role_name.to_s.camelcase}}
              end*""
            }
          end

          class TestBy#{base_type.name}Sub
            identified_by :#{base_type.name.snakecase}_sub_val#{
              @role_names.map do |role_name|
                %Q{
            #{
              (role_name == (base_type.name.snakecase+'_sub_val').to_sym ? "one_to_one :#{role_name}" : "has_one :#{role_name}")
            }
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

        begin
          Mod.module_eval code
        rescue Exception => e
          puts "Failure: #{e}"
          puts "Failed on: <<END\n#{code}\nEND"
        end
      end
    end

    @constellation = ActiveFacts::API::Constellation.new(Mod)

    # Simple Values
    @int = 0
    @real = 0.0
    @auto_counter = 0
    @new_auto_counter = :new
    @string = "zero"
    @date = [2008, 04, 19]
    @date_time = [2008, 04, 19, 10, 28, 14]
    @decimal = BigDecimal.new('98765432109876543210')
    @guid = '01234567-89ab-cdef-0123-456789abcdef'

    # Value Type instances
    @int_value = @constellation.IntVal(1)
    @real_value = @constellation.RealVal(1.0)
    @auto_counter_value = @constellation.AutoCounterVal(1)
    @new_auto_counter_value = @constellation.AutoCounterVal(:new)
    @string_value = @constellation.StringVal("one")
    @date_value = @constellation.DateVal(2008, 04, 20)
    # Parse the date:
    @date_value = @constellation.DateVal('2nd Nov 2001')
    d = ::Date.civil(2008, 04, 20)
    @date_time_value = Mod::DateTimeVal.civil(2008, 04, 20, 10, 28, 14)
    # This next isn't in the same pattern; it makes a Decimal from a BigDecimal rather than a String (coverage reasons)
    @decimal_value = @constellation.DecimalVal(BigDecimal.new('98765432109876543210'))
    @guid_value = @constellation.GuidVal(:new)
    @guid_as_value = @constellation.GuidVal(@guid)

    # Value SubType instances
    @int_sub_value = @constellation.IntSubVal(4)
    @real_sub_value = @constellation.RealSubVal(4.0)
    @auto_counter_sub_value = @constellation.AutoCounterSubVal(4)
    @auto_counter_sub_value_new = @constellation.AutoCounterSubVal(:new)
    @string_sub_value = @constellation.StringSubVal("five")
    @date_sub_value = @constellation.DateSubVal(2008, 04, 25)
    @date_time_sub_value = @constellation.DateTimeSubVal(::DateTime.civil(2008, 04, 26, 10, 28, 14))
    # This next isn't in the same pattern; it makes a Decimal from a BigNum rather than a String (coverage reasons)
    @decimal_sub_value = @constellation.DecimalSubVal(98765432109876543210)
    @guid_sub_value = @constellation.GuidSubVal(:new)

    # Entities identified by Value Type, SubType and Entity-by-value-type instances
    @test_by_int = @constellation.TestByInt(2)
    @test_by_real = @constellation.TestByReal(2.0)
    @test_by_auto_counter = @constellation.TestByAutoCounter(2)
    @test_by_auto_counter_new = @constellation.TestByAutoCounter(:new)
    @test_by_string = @constellation.TestByString("two")
    @test_by_date = @constellation.TestByDate(Date.civil(2008,04,28))
    #@test_by_date = @constellation.TestByDate(2008,04,28)
    # Array packing/unpacking obfuscates the following case
    # @test_by_date_time = @constellation.TestByDateTime([2008,04,28,10,28,15])
    # Pass an array of values directly to DateTime.civil:
    @test_by_date_time = @constellation.TestByDateTime(@date_time_value)
    #@test_by_date_time = @constellation.TestByDateTime(DateTime.civil(2008,04,28,10,28,15))
    @test_by_decimal = @constellation.TestByDecimal('98765432109876543210')

    @test_by_guid = @constellation.TestByGuid(@guid)
    @constellation.TestByGuid[[@guid_as_value]].should_not be_nil

    @test_by_int_sub = @constellation.TestByIntSub(2)
    @test_by_real_sub = @constellation.TestByRealSub(5.0)
    @test_by_auto_counter_sub = @constellation.TestByAutoCounterSub(6)
    @test_by_auto_counter_new_sub = @constellation.TestByAutoCounterSub(:new)
    @test_by_string_sub = @constellation.TestByStringSub("six")
    @test_by_date_sub = @constellation.TestByDateSub(Date.civil(2008,04,27))
    # Array packing/unpacking obfuscates the following case
    # @test_by_date_time_sub = @constellation.TestByDateTimeSub([2008,04,29,10,28,15])
    # Pass an array of values directly to DateTime.civil:
    @test_by_date_time_sub = @constellation.TestByDateTimeSub(@date_time_value)
    @test_by_decimal_sub = @constellation.TestByDecimalSub('98765432109876543210')
    @test_by_guid_sub = @constellation.TestByGuidSub('01234567-89ab-cdef-0123-456789abcdef')

    @test_by_int_entity = @constellation.TestByIntEntity(@test_by_int)
    @test_by_real_entity = @constellation.TestByRealEntity(@test_by_real)
    @test_by_auto_counter_entity = @constellation.TestByAutoCounterEntity(@test_by_auto_counter)
    @test_by_auto_counter_new_entity = @constellation.TestByAutoCounterEntity(@test_by_auto_counter_new)
    @test_by_string_entity = @constellation.TestByStringEntity(@test_by_string)
    @test_by_date_entity = @constellation.TestByDateEntity(@test_by_date)
    @test_by_date_time_entity = @constellation.TestByDateTimeEntity(@test_by_date_time)
    @test_by_decimal_entity = @constellation.TestByDecimalEntity(@test_by_decimal)
    @test_by_guid_entity = @constellation.TestByGuidEntity(@test_by_guid)
    @constellation.TestByGuidEntity[[@test_by_guid.identifying_role_values]].should_not be_nil

    # Entity subtypes
    @test_sub_by_int = @constellation.TestSubByInt(2*2)
    @test_sub_by_real = @constellation.TestSubByReal(2.0*2)
    @test_sub_by_auto_counter = @constellation.TestSubByAutoCounter(2*2)
    @test_sub_by_auto_counter_new = @constellation.TestSubByAutoCounter(:new)
    @test_sub_by_string = @constellation.TestSubByString("twotwo")
    @test_sub_by_date = @constellation.TestSubByDate(Date.civil(2008,04*2,28))
    # Array packing/unpacking obfuscates the following case
    # @test_sub_by_date_time = @constellation.TestSubByDateTime([2008,04*2,28,10,28,15])
    @test_sub_by_decimal = @constellation.TestSubByDecimal('987654321098765432109')
    @test_sub_by_guid = @constellation.TestSubByGuid('01234567-89ab-cdef-0123-456789abcde0')

    # These arrays get zipped together in various ways. Keep them aligned.
    @values = [
        @int, @real, @auto_counter, @new_auto_counter,
        @string, @date, @date_time, @decimal, @guid
      ]
    @classes = [
        Int, Real, AutoCounter, AutoCounter,
        String, Date, DateTime, Decimal, Guid
      ]
    @value_types = [
        Mod::IntVal, Mod::RealVal, Mod::AutoCounterVal, Mod::AutoCounterVal,
        Mod::StringVal, Mod::DateVal, Mod::DateTimeVal, Mod::DecimalVal,
        Mod::GuidVal,
        Mod::IntSubVal, Mod::RealSubVal, Mod::AutoCounterSubVal, Mod::AutoCounterSubVal,
        Mod::StringSubVal, Mod::DateSubVal, Mod::DateTimeSubVal, Mod::DecimalSubVal,
        Mod::GuidSubVal,
        ]
    @value_instances = [
        @int_value, @real_value, @auto_counter_value, @new_auto_counter_value,
        @string_value, @date_value, @date_time_value, @decimal_value, @guid_value,
        @int_sub_value, @real_sub_value, @auto_counter_sub_value, @auto_counter_sub_value_new,
        @string_sub_value, @date_sub_value, @date_time_sub_value, @decimal_sub_value, @guid_sub_value,
        @int_value, @real_value, @auto_counter_value, @new_auto_counter_value,
        @string_value, @date_value, @date_time_value, @decimal_value, @guid_value,
      ]
    @entity_types = [
        Mod::TestByInt, Mod::TestByReal, Mod::TestByAutoCounter, Mod::TestByAutoCounter,
        Mod::TestByString, Mod::TestByDate, Mod::TestByDateTime, Mod::TestByDecimal,
        Mod::TestByGuid,
        Mod::TestByIntSub, Mod::TestByRealSub, Mod::TestByAutoCounterSub, Mod::TestByAutoCounterSub,
        Mod::TestByStringSub, Mod::TestByDateSub, Mod::TestByDateTimeSub, Mod::TestByDecimalSub,
        Mod::TestByGuidSub,
        Mod::TestSubByInt, Mod::TestSubByReal, Mod::TestSubByAutoCounter, Mod::TestSubByAutoCounter,
        Mod::TestSubByString, Mod::TestSubByDate, Mod::TestSubByDateTime, Mod::TestByDecimalEntity,
        Mod::TestByGuidEntity,
      ]
    @entities = [
        @test_by_int, @test_by_real, @test_by_auto_counter, @test_by_auto_counter_new,
        @test_by_string, @test_by_date, @test_by_date_time, @test_by_decimal,
        @test_by_guid,
        @test_by_int_sub, @test_by_real_sub, @test_by_auto_counter_sub, @test_by_auto_counter_new_sub,
        @test_by_string_sub, @test_by_date_sub, @test_by_date_time_sub, @test_by_decimal_sub,
        @test_by_guid_sub,
        @test_sub_by_int, @test_sub_by_real, @test_sub_by_auto_counter, @test_sub_by_auto_counter_new,
        @test_sub_by_string, @test_sub_by_date, @test_sub_by_date_time, @test_sub_by_decimal,
        @test_sub_by_guid,
      ].compact
    @entities_by_entity = [
        @test_by_int_entity,
        @test_by_real_entity,
        @test_by_auto_counter_entity,
        @test_by_auto_counter_new_entity,
        @test_by_string_entity,
        @test_by_date_entity,
        @test_by_date_time_entity,
        @test_by_decimal_entity,
        @test_by_guid_entity,
      ].compact
    @entities_by_entity_types = [
        Mod::TestByIntEntity, Mod::TestByRealEntity, Mod::TestByAutoCounterEntity, Mod::TestByAutoCounterEntity,
        Mod::TestByStringEntity, Mod::TestByDateEntity, Mod::TestByDateTimeEntity, Mod::TestByDecimalEntity,
        Mod::TestByGuidEntity,
      ]
    @test_role_names = [
        :int_value, :real_value, :auto_counter_value, :auto_counter_value,
        :string_value, :date_value, :date_time_value, :decimal_value,
        :guid_value,
        :int_sub_value, :real_sub_value, :auto_counter_sub_value, :auto_counter_sub_value,
        :string_sub_value, :date_sub_value, :date_time_sub_value, :decimal_sub_value,
        :guid_sub_value,
        :int_value, :real_value, :auto_counter_value, :auto_counter_value,
        :string_value, :date_value, :date_time_value, :decimal_value,
        :guid_value,
      ]
    @role_values = [
        3, 4.0, 5, 6,
        "three", Date.civil(2008,4,21), DateTime.civil(2008,4,22,10,28,16),
        '98765432109876543210',
        '01234567-89ab-cdef-0123-456789abcdef'
      ]
    @role_alternate_values = [
        4, 5.0, 6, 7,
        "four", Date.civil(2009,4,21), DateTime.civil(2009,4,22,10,28,16),
        '98765432109876543211',
        '01234567-89ab-cdef-0123-456789abcdef'
      ]
    @subtype_role_instances = [
        @constellation.IntSubVal(6), Mod::RealSubVal.new(6.0),
        @constellation.AutoCounterSubVal(:new), Mod::AutoCounterSubVal.new(8),
        @constellation.StringSubVal("seven"),
        @constellation.DateSubVal(2008,4,29), @constellation.DateTimeSubVal(2008,4,30,10,28,16),
        @constellation.DecimalSubVal('98765432109876543210'),
        @constellation.DecimalSubVal('01234567-89ab-cdef-0123-456789abcdef'),
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
            role = entity_type.all_role(ir)
            role.should_not be_nil
            counterpart_object_type = role.counterpart.object_type
            verbalisation.should =~ %r{\b#{counterpart_object_type.basename}\b}
          end
      end
    end

    it "should inspect" do
      (@value_instances+@entities+@entities_by_entity).each_with_index do |object, i|
	begin
	  object.inspect
	rescue Exception => e
	  puts "FAILED on #{object.class} at #{i}"
	  raise
	end
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
        entity.respond_to?(:verbalise).should be_true
        verbalisation = entity.verbalise
        verbalisation.should =~ %r{\b#{entity.class.basename}\b}
        entity.class.identifying_role_names.each do |ir|
            role = entity.class.all_role(ir)
            role.should_not be_nil
            counterpart_object_type = role.counterpart.object_type
            verbalisation.should =~ %r{\b#{counterpart_object_type.basename}\b}
          end
      end
    end
  end

  it "should respond to constellation" do
    (@value_instances+@entities+@entities_by_entity).each do |instance|
      next if instance == nil
      instance.respond_to?(:constellation).should be_true
    end
  end

  it "should return the module in response to .vocabulary()" do
    (@value_types+@entity_types).zip((@value_instances+@entities+@entities_by_entity)).each do |object_type, instance|
      next if instance == nil
      instance.class.vocabulary.should == Mod
    end
  end

  it "should disallow treating an unresolved AutoCounter as an integer" do
    c = ActiveFacts::API::Constellation.new(Mod)
    a = c.AutoCounterVal(:new)
    lambda {
      b = 2 + a
    }.should raise_error(TypeError)
    a.assign(3)
    lambda {
      b = 2 + a
      a.to_i
    }.should_not raise_error
  end

  it "should complain when not enough identifying values are provided for an entity" do
    c = ActiveFacts::API::Constellation.new(Mod)
    lambda {
      c.TestByInt(:int_val => nil)
    }.should raise_error(ActiveFacts::API::MissingMandatoryRoleValueException)
  end

  it "should complain when too many identifying values are provided for an entity" do
    c = ActiveFacts::API::Constellation.new(Mod)
    lambda {
      c.TestByInt(2, 3)
    }.should raise_error(ActiveFacts::API::UnexpectedIdentifyingValueException)
  end

  it "should complain when wrong type is used for an entity" do
    c = ActiveFacts::API::Constellation.new(Mod)
    lambda {
      c.TestByInt("Not an Int")
    }.should raise_error(ArgumentError)
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
