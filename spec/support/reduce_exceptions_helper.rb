if ENV["RSPEC_REPORT_EXCEPTIONS"]
  class Exception
    alias_method :old_initialize, :initialize

    def self.exceptions_seen
      @@seen ||= {}
    end

    def self.see args
      stack = caller[1..-1]
      # Don't show expected exceptions or RSpec internal ones
      return if caller.detect{|s| s =~ %r{rspec/matchers/raise_error}} or
	self.name =~ /^RSpec::/
      stack.reject!{|s| s =~ %r{/rspec/}}
      key = stack[0,4]+[self.name]
      return if exceptions_seen[key]

      exceptions_seen[key] = show = stack
      args[0] = args[0].to_str if args[0].class.name == "NameError::message"
      puts "#{self.name}#{args.inspect}:\n\t#{show*"\n\t"}"
    end

    def initialize *args, &b
      self.class.see args

      send(:old_initialize, *args, &b)
    end
  end
end
