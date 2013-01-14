#
# ActiveFacts tests: Value instances in the Runtime API
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'activefacts/api'

describe Date do
  it "should construct with no arguments" do
    proc {
      @d = Date.new()
    }.should_not raise_error
    @d.year.should == -4712
  end

  it "should construct with a nil argument" do
    proc {
      @d = Date.new_instance(nil, nil)
    }.should_not raise_error
    @d.year.should == -4712
  end

  it "should construct with a full arguments" do
    proc {
      @d = Date.civil(2012, 10, 31)
    }.should_not raise_error
    @d.to_s.should == "2012-10-31"
  end

=begin
  it "should be encodable in JSON" do
    proc {
      @d = Date.new(2012, 10, 31)
      @d.to_json.should == "REVISIT"
    }.should_not raise_error
  end
=end

end
