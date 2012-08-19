describe ActiveFacts::API::InstanceIndexKey do
  it "should be negative for ['a'] <=> ['b']" do
    vt1 = ActiveFacts::API::InstanceIndexKey.new(['a'])
    vt2 = ActiveFacts::API::InstanceIndexKey.new(['b'])
    vt1.<=>(vt2).should == -1
  end

  it "should be equal for ['a'] <=> ['a']" do
    vt1 = ActiveFacts::API::InstanceIndexKey.new(['a'])
    vt2 = ActiveFacts::API::InstanceIndexKey.new(['a'])
    vt1.<=>(vt2).should == 0
  end

  it "should be negative for ['b'] <=> ['a']" do
    vt1 = ActiveFacts::API::InstanceIndexKey.new(['b'])
    vt2 = ActiveFacts::API::InstanceIndexKey.new(['a'])
    vt1.<=>(vt2).should == 1
  end

  it "should fall back on string comparison with nil values" do
    vt1 = ActiveFacts::API::InstanceIndexKey.new([nil])
    vt2 = ActiveFacts::API::InstanceIndexKey.new(['a'])
    vt1.<=>(vt2).should == 1

    vt1 = ActiveFacts::API::InstanceIndexKey.new([nil])
    vt2 = ActiveFacts::API::InstanceIndexKey.new([1])
    vt1.<=>(vt2).should == 1
  end
end
