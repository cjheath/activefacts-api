describe ActiveFacts::API::ComparableHashKey do
  it "should be negative for ['a'] <=> ['b']" do
    vt1 = ActiveFacts::API::ComparableHashKey.new(['a'])
    vt2 = ActiveFacts::API::ComparableHashKey.new(['b'])
    vt1.<=>(vt2).should == -1
  end

  it "should be equal for ['a'] <=> ['a']" do
    vt1 = ActiveFacts::API::ComparableHashKey.new(['a'])
    vt2 = ActiveFacts::API::ComparableHashKey.new(['a'])
    vt1.<=>(vt2).should == 0
  end

  it "should be negative for ['b'] <=> ['a']" do
    vt1 = ActiveFacts::API::ComparableHashKey.new(['b'])
    vt2 = ActiveFacts::API::ComparableHashKey.new(['a'])
    vt1.<=>(vt2).should == 1
  end

  it "should fall back on string comparison with nil values" do
    vt1 = ActiveFacts::API::ComparableHashKey.new([nil])
    vt2 = ActiveFacts::API::ComparableHashKey.new(['a'])
    vt1.<=>(vt2).should == 1

    vt1 = ActiveFacts::API::ComparableHashKey.new([nil])
    vt2 = ActiveFacts::API::ComparableHashKey.new([1])
    vt1.<=>(vt2).should == 1
  end
end
