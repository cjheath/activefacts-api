#
# ActiveFacts tests: Roles of object_type classes in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#

include ActiveFacts::API

describe ComparableHashKey do
  it "should be negative for ['a'] <=> ['b']" do
    vt1 = ComparableHashKey.new(['a'])
    vt2 = ComparableHashKey.new(['b'])
    vt1.<=>(vt2).should == -1
  end

  it "should be equal for ['a'] <=> ['a']" do
    vt1 = ComparableHashKey.new(['a'])
    vt2 = ComparableHashKey.new(['a'])
    vt1.<=>(vt2).should == 0
  end

  it "should be negative for ['b'] <=> ['a']" do
    vt1 = ComparableHashKey.new(['b'])
    vt2 = ComparableHashKey.new(['a'])
    vt1.<=>(vt2).should == 1
  end

  it "should fall back on string comparison with nil values" do
    vt1 = ComparableHashKey.new([nil])
    vt2 = ComparableHashKey.new(['a'])
    vt1.<=>(vt2).should == 1

    vt1 = ComparableHashKey.new([nil])
    vt2 = ComparableHashKey.new([1])
    vt1.<=>(vt2).should == 1
  end
end
