require 'activefacts/api'

module TestMultiPartIdentifierModule
  class ParentId < AutoCounter
    value_type
  end

  class Parent
    identified_by :parent_id
    one_to_one :parent_id
  end

  class Position < Int
    value_type
  end

  class Child
    identified_by :parent, :position
    has_one :parent
    has_one :position
  end
end

describe "Multi-part identifiers" do
  before :each do
    @c = ActiveFacts::API::Constellation.new(TestMultiPartIdentifierModule)
    @p = @c.Parent(:new)
    @c0 = @c.Child(@p, 0)
    @c2 = @c.Child(@p, 2)
    @c1 = @c.Child(@p, 1)
  end

  it "should allow children to be found in the instance index" do
    pv = @p.identifying_role_values
    @c.Child[[pv, 0]].should == @c0
    @c.Child[[pv, 1]].should == @c1
    @c.Child[[pv, 2]].should == @c2
  end

  it "should sort child keys in the instance index" do
    pending "Key sorting is not supported on this index" unless @c.Child.sort
    @c.Child.keys.should == [[[@p.parent_id], 0], [[@p.parent_id], 1], [[@p.parent_id], 2]]
    @c.Child.map{|k, c| c.position}.should == [@c0.position, @c1.position, @c2.position]
  end

  it "should index children in the parent's RoleValues" do
    @p.all_child.size.should == 3
  end

  it "should allow children to be found in the instance index by the residual key" do
    pending "RoleValues use the whole key, not the residual key" do
      @c.Child[[0]].should == @c0
      @c.Child[[1]].should == @c1
      @c.Child[[2]].should == @c2
    end
  end

  it "should allow children to be found in the instance index by the whole key" do
    @c.Child[[[@p.parent_id], 0]].should == @c0
    @c.Child[[[@p.parent_id], 1]].should == @c1
    @c.Child[[[@p.parent_id], 2]].should == @c2
  end

  it "should sort children in the parent's RoleValues" do
    pending "Key sorting is not supported in this version" if @p.all_child.instance_variable_get("@a").kind_of? Array
    @p.all_child.to_a[0].should == @c0
    @p.all_child.to_a[1].should == @c1
    @p.all_child.to_a[2].should == @c2
  end

  it "should have a correct key for each child in the parent's RoleValues" do
    pending "Key sorting is not supported in this version" if @p.all_child.instance_variable_get("@a").kind_of? Array
    @p.all_child.keys[0].should == [[@p.parent_id], 0]
    @p.all_child.keys[1].should == [[@p.parent_id], 1]
    @p.all_child.keys[2].should == [[@p.parent_id], 2]
  end
end
