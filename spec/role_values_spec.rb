#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'rspec'
require 'activefacts/api'

VALUE_TYPES = Int, Real, AutoCounter, String, Date, DateTime, Decimal
RAW_VALUES = [2, 3.0, 4, "5", Date.new(2008, 04, 20), DateTime.new(2008, 04, 20, 10, 28, 14)]
ALT_VALUES = [3, 4.0, 5, "6", Date.new(2009, 04, 20), DateTime.new(2009, 04, 20, 10, 28, 14)]
VALUE_SUB_FOR_VALUE = {}
VALUES_FOR_TYPE = VALUE_TYPES.zip(RAW_VALUES, ALT_VALUES).inject({}) do |h, (vt, v1, v2)|
    next h unless v1 and v2
    h[vt] = [v1, v2]
    h
  end
VALUE_TYPE_FOR_OBJECT_TYPE = {}
OBJECT_TYPES = []

module TestValueTypesModule
  class ESCID < AutoCounter
    value_type
  end
  BASE_VALUE_TYPE_ROLE_NAMES = VALUE_TYPES.map { |base_type| base_type.name.snakecase }
  VALUE_TYPE_ROLE_NAMES = BASE_VALUE_TYPE_ROLE_NAMES.map { |n| [ :"#{n}_value", :"#{n}_sub_value" ] }.flatten
  VALUE_TYPES.map do |value_type|
    code = <<-END
      class #{value_type.name}Value < #{value_type.name}
        value_type
      end

      class #{value_type.name}ValueSub < #{value_type.name}Value
        # Note no new "value_type" is required here, it comes through inheritance
      end

      class #{value_type.name}Entity
        identified_by :#{identifying_role_name = "id_#{value_type.name.snakecase}_value"}
        has_one :#{identifying_role_name}, :class => #{value_type.name}Value
      end

      class #{value_type.name}EntitySub < #{value_type.name}Entity
      end

      class #{value_type.name}EntitySubCtr < #{value_type.name}Entity
        identified_by :counter
        has_one :counter, :class => "ESCID"
      end

      VALUE_SUB_FOR_VALUE[#{value_type.name}Value] = #{value_type.name}ValueSub
      classes = [
          #{value_type.name}Value,
          #{value_type.name}ValueSub,
          #{value_type.name}Entity,
          #{value_type.name}EntitySub,
          #{value_type.name}EntitySubCtr,
        ]
      OBJECT_TYPES.concat(classes)
      classes.each { |klass| VALUE_TYPE_FOR_OBJECT_TYPE[klass] = value_type }
    END
    eval code
  end
  OBJECT_TYPE_NAMES = OBJECT_TYPES.map{|object_type| object_type.basename}

  class Octopus
    identified_by :zero
    has_one :zero, :class => IntValue
    maybe :has_a_unary
    OBJECT_TYPE_NAMES.each do |object_type_name|
      has_one object_type_name.snakecase.to_sym
      one_to_one ("one_"+object_type_name.snakecase).to_sym, :class => object_type_name
    end
  end
end

describe "Roles of an Object Type" do

  it "should return a roles collection" do
    roles = TestValueTypesModule::Octopus.roles
    roles.should_not be_nil
    roles.size.should == 2+VALUE_TYPES.size*5*2

    # Quick check of role metadata:
    roles.each do |role_name, role|
      role.owner.modspace.should == TestValueTypesModule
      if !role.counterpart
        role.should be_unary
      else
        role.counterpart.owner.modspace.should == TestValueTypesModule
      end
    end
  end
end

describe "Object type role values" do
  def object_identifying_parameters object_type_name, value
    if object_type_name =~ /^(.*)EntitySubCtr$/
      [{ :"id_#{$1.snakecase}_value" => value, :counter => :new}]
    else
      [value]
    end
  end

  describe "Instantiating bare objects" do
    OBJECT_TYPES.each do |object_type|
      required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type]
      object_type_name = object_type.basename
      values = VALUES_FOR_TYPE[required_value_type]
      next unless values

      it "should allow instantiation of a bare #{object_type_name}" do
        object_identifying_parameters =
          if object_type_name =~ /^(.*)EntitySubCtr$/
            [{ :"id_#{$1.snakecase}_value" => values[0], :counter => :new}]
          else
            [values[0]]
          end
        object = object_type.new(*object_identifying_parameters)
        object.class.should == object_type
        object.constellation.should be_nil
      end
    end
  end

  describe "A constellation" do
    before :each do
      @constellation = ActiveFacts::API::Constellation.new(TestValueTypesModule)
    end

    OBJECT_TYPES.each do |object_type|
      required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type]
      object_type_name = object_type.basename
      values = VALUES_FOR_TYPE[required_value_type]

      it "should return an initially empty instance index collection for #{object_type_name}" do
        @constellation.send(object_type_name).should be_empty
      end

      next unless values

      it "should allow assertion of an #{object_type_name} instance using #{values[0].inspect}" do
        # REVISIT: Assertion of a subtype having the same identifier as a supertype is... dodgey.
        # What should it do? Migrate the previous object to its subtype?
        object = @constellation.send(object_type_name, *object_identifying_parameters(object_type_name, values[0]))

        # Make sure we got what we expected:
        object.class.should == object_type

        # Make sure the instance index contains this single object:
        instances = @constellation.send(object_type_name)
        instances.size.should == 1
        instances.map{|k,o| o}.first.should == object
        unless object.class.is_entity_type
          # Look up value types using the value instance, not just the raw value:
          instances[object].should == object
        end

        # Make sure all the identifying roles are populated correctly:
        if object_type.respond_to?(:identifying_roles)
          object.class.identifying_roles.each do |identifying_role|
            identifying_value = object.send(identifying_role.name)
            identifying_value.should_not be_nil

            counterpart_object_type = identifying_role.counterpart_object_type
            role_superclasses = [ counterpart_object_type.superclass, counterpart_object_type.superclass.superclass ]
            # Autocounter values do not compare to Integers:
            unless role_superclasses.include?(AutoCounter) or identifying_role.owner.basename =~ /Entity/
              identifying_value.should == identifying_role.owner.new(*values[0])
            end
          end
        end
      end

      if object_type.respond_to?(:identifying_roles)
        # REVISIT: Here, there are many possible problems with re-assigning identifying role values. We need tests!
        # The implementation will need to be reworked to detect problems and reverse any partial changes before chucking an exception
=begin
        it "should not allow re-assigning a #{object_type_name} entity's identifying role value from #{values[0]} to #{values[1]}" do
          object = @constellation.send(object_type_name, *object_identifying_parameters(object_type_name, values[0]))
          object.class.identifying_roles.each do |identifying_role|
            next if identifying_role.name == :counter
            lambda {
              object.send(:"#{identifying_role.name}=", values[1])
            }.should raise_error
          end
        end
=end

        it "should allow nullifying and reassigning a #{object_type_name} entity's identifying role value" do
          object = @constellation.send(object_type_name, *object_identifying_parameters(object_type_name, values[0]))
          object.class.identifying_roles.each do |identifying_role|
            next if identifying_role.name == :counter
            assigned = object.send(:"#{identifying_role.name}=", nil)
            assigned.should be_nil
            object.send(:"#{identifying_role.name}=", values[1])
          end
        end
      else
        it "should allow initialising value type #{object_type.name} with an instance of that value type" do
          bare_value = object_type.new(*object_identifying_parameters(object_type_name, values[0]))
          object = @constellation.send(object_type_name, bare_value)

          # Now link the bare value to an Octopus:
          octopus = @constellation.Octopus(0)
          octopus_role_name = :"octopus_as_one_#{object_type_name.snakecase}"
          bare_value.send(:"#{octopus_role_name}=", octopus)
          counterpart_name = bare_value.class.roles[octopus_role_name].counterpart.name

          # Create a reference by assigning the object from a RoleProxy:
          proxy = octopus.send(counterpart_name)
          #proxy.should be_respond_to(:__getobj__)
          object2 = @constellation.send(object_type_name, proxy)
          object2.should == object
        end
      end
    end

  end

  describe "Role values" do
    before :each do
      @constellation = ActiveFacts::API::Constellation.new(TestValueTypesModule)
      @object = @constellation.Octopus(0)
      @roles = @object.class.roles
    end

    it "should return its constellation and vocabulary" do
      # Strictly, these are not role value tests
      @object.constellation.should == @constellation
      @object.constellation.vocabulary.should == TestValueTypesModule
      @object.class.vocabulary.should == TestValueTypesModule
    end

    TestValueTypesModule::Octopus.roles.each do |role_name, role|
      next if role_name == :zero

      it "should respond to getting its #{role_name} role" do
        @object.should be_respond_to role.name
      end

      it "should respond to setting its #{role_name} role" do
        @object.should be_respond_to :"#{role.name}="
      end

      if role.unary?
        it "should allow its #{role_name} unary role to be assigned and reassigned" do
          @object.has_a_unary.should be_nil
          @object.has_a_unary = true
          @object.has_a_unary.should == true
          @object.has_a_unary = 23
          @object.has_a_unary.should == true
          @object.has_a_unary = false
          @object.has_a_unary.should be_false
          @object.has_a_unary = nil
          @object.has_a_unary.should be_nil
        end
      else
        it "should allow its #{role_name} role to be assigned and reassigned a base value" do
          object_type = role.counterpart.owner
          required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type]
          values = VALUES_FOR_TYPE[required_value_type]
          next unless values
          value = object_identifying_parameters(object_type.basename, values[0])

          # Set the role to the first value:
          assigned = @object.send(:"#{role_name}=", value)
          assigned.class.should == object_type
          fetched = @object.send(role_name)
          fetched.should == assigned

          if role.counterpart.unique      # A one-to-one
            # The counterpart should point back at us
            assigned.send(role.counterpart.name).should == @object
          else                                            # A many-to-one
            # The counterpart should include us in its RoleValues
            reflection = assigned.send(role.counterpart.name)
            reflection.should_not be_empty
            reflection.size.should == 1
            reflection.should be_include(@object)
          end

          # Update the role to the second value:
          value = object_identifying_parameters(object_type.basename, values[1])
          assigned2 = @object.send(:"#{role_name}=", value)
          assigned2.class.should == object_type
          fetched = @object.send(role_name)
          fetched.should == assigned2

          if role.counterpart.unique                      # A one-to-one
            # REVISIT: The old counterpart role should be nullified
            #assigned.send(role.counterpart.name).should be_nil

            # The counterpart should point back at us
            assigned2.send(role.counterpart.name).should == @object
          else                                            # A many-to-one
            # REVISIT: The old counterpart RoleValues should be empty
            reflection = assigned2.send(role.counterpart.name)
            #reflection.size.should == 0

            # The counterpart should include us in its RoleValues
            reflection2 = assigned2.send(role.counterpart.name)
            reflection2.size.should == 1
            reflection2.should be_include(@object)
          end

          # Nullify the role
          nullified = @object.send(:"#{role_name}=", nil)
          nullified.should be_nil
          if role.counterpart.unique                      # A one-to-one
            assigned2.send(role.counterpart.name).should be_nil
          else                                            # A many-to-one
            reflection3 = assigned2.send(role.counterpart.name)
            reflection3.size.should == 0
          end
        end

        it "should allow its #{role_name} role to be assigned and reassigned a base value" do
          object_type = role.counterpart.owner
          required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type]
          values = VALUES_FOR_TYPE[required_value_type]
          next unless values
          value = object_identifying_parameters(object_type.basename, values[0])

          # Set the role to the first value:
          assigned = @object.send(:"#{role_name}=", value)
          fetched = @object.send(role_name)
          fetched.class.should == object_type
        end

        it "should allow its #{role_name} role to be assigned a value instance" do
          object_type = role.counterpart.owner
          required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type]
          values = VALUES_FOR_TYPE[required_value_type]
          next unless values
          value = @constellation.send(object_type.basename, *object_identifying_parameters(object_type.basename, values[0]))

          assigned = @object.send(:"#{role_name}=", value)
          assigned.class.should == object_type
          fetched = @object.send(role_name)
          fetched.should == assigned

          # Nullify the role
          nullified = @object.send(:"#{role_name}=", nil)
          nullified.should be_nil
        end

        it "should allow its #{role_name} role to be assigned a value subtype instance, retaining the subtype" do
          object_type = role.counterpart.owner
          required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type] # The raw value type
          values = VALUES_FOR_TYPE[required_value_type]
          object_type = VALUE_SUB_FOR_VALUE[object_type]  # The value type subtype
          next unless values and object_type
          value = @constellation.send(object_type.basename, *object_identifying_parameters(object_type.basename, values[0]))
          assigned = @object.send(:"#{role_name}=", value)
          # This requires the declared type, not the subtype:
          # assigned.class.should == role.counterpart.owner
          # This requires the subtype, as the test implies:
          assigned.class.should == object_type
          fetched = @object.send(role_name)
          fetched.should == assigned
        end
      end

      unless !role.counterpart or         # A unary
          role.counterpart.unique or      # A one-to-one
          VALUES_FOR_TYPE[VALUE_TYPE_FOR_OBJECT_TYPE[role.counterpart.owner]] == nil
        describe "Operations on #{role.counterpart.owner.basename} RoleValues collections" do
          before :each do
            object_type = role.counterpart.owner
            required_value_type = VALUE_TYPE_FOR_OBJECT_TYPE[object_type]
            values = VALUES_FOR_TYPE[required_value_type]
            return unless values
            value = object_identifying_parameters(object_type.basename, values[0])
            assigned = @object.send(:"#{role_name}=", value)
            @role_values = assigned.send(role.counterpart.name)
          end

          it "should support Array addition" do
            added = @role_values + ["foo"]
            added.class.should == Array
            added.size.should == 2
          end

          it "should support Array subtraction" do
            # We only added one value, so subtracting it leaves us empty
            counterpart_value = @role_values.single
            (@role_values - [counterpart_value]).should be_empty
          end

          it "should support each" do
            count = 0
            @role_values.each { |rv| count += 1 }
            count.should == 1
          end

          it "should support detect" do
            @role_values.detect { |rv| true }.should be_true
          end

          it "should verbalise" do
            @role_values.verbalise.should =~ /Octopus.*Zero '0'/
          end

        end
      end

    end

  end
end
