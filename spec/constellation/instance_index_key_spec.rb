describe InstanceIndexKey do
  it "should be negative for ['a'] <=> ['b']" do
    vt1 = InstanceIndexKey.new(['a'])
    vt2 = InstanceIndexKey.new(['b'])
    vt1.<=>(vt2).should == -1
  end

  it "should be equal for ['a'] <=> ['a']" do
    vt1 = InstanceIndexKey.new(['a'])
    vt2 = InstanceIndexKey.new(['a'])
    vt1.<=>(vt2).should == 0
  end

  it "should be negative for ['b'] <=> ['a']" do
    vt1 = InstanceIndexKey.new(['b'])
    vt2 = InstanceIndexKey.new(['a'])
    vt1.<=>(vt2).should == 1
  end

  it "should fall back on string comparison with nil values" do
    vt1 = InstanceIndexKey.new([nil])
    vt2 = InstanceIndexKey.new(['a'])
    vt1.<=>(vt2).should == 1

    vt1 = InstanceIndexKey.new([nil])
    vt2 = InstanceIndexKey.new([1])
    vt1.<=>(vt2).should == 1
  end
end
