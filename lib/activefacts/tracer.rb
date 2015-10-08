#
# ActiveFacts Tracer.
#
# The trace() method supports indented tracing.
#
# Trace keys:
# The first argument is normally a symbol which is the key for related trace calls.
# Set the TRACE environment variable to enable it, or add trace.enable(:key) to a CLI.
# A call to trace without a first symbol argument is always enabled (as if by :all)
#
# Message arguments:
# Each subsequent argument is either
#  - a String (or anything that can be join()ed), or
#  - a Proc (or anything that can be called) that returns such a string.
# Proc arguments will be called only if the trace key is enabled.
# If the key is enabled (or not present) the Trace strings will be joined and emitted.
#
# Trace blocks:
# A block passed to the trace method will always be called, and trace will always return its value.
# Any trace emitted from within such a block will be indented if the current trace key is enabled.
#
# Special trace key options for nesting blocks:
# - A trace key ending in _ is enabled if the base key is enabled, but enables all
#   nested trace calls whether or not their key is enabled.
# - A trace key ending in ? is enabled if the base key is enabled, but is emitted
#   only if (and just before) the nested block emits a trace message
# 
# Testing whether a trace key is enabled:
# A call to trace with a key but without a block will return true if the key is enabled
#
# A call to trace with no arguments returns the Tracer object itself.
#
# Built-in trace keys and behaviour:
#   help - list (at exit) all trace keys that became available during the run
#   all - enable all trace keys
#   keys - display the trace key for every trace message (automatically enabled by :all)
#   debug - prepare a Ruby debugger at the start of the run, so it has the full context available
#   firstaid - enter the debugger inside the Exception constructor so you can inspect the local context
#   trap - trap SIGINT (^C) in a block that allows inspecting or continuing execution (not all debuggers support this)
#   flame - use ruby-prof-flamegraph to display the performance profile as a flame graph using SVG
#
# The debugger is chosen from ENV['DEBUG_PREFERENCE'] or the first to load of: byebug, pry. debugger, ruby-trace
#
# Copyright (c) 2009-2015 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  (class << self; self; end).class_eval do
    attr_accessor :tracer
  end

  class Tracer
    def initialize
      @indent = 0	# Current nesting level of enabled trace blocks
      @nested = false   # Set when a block enables all enclosed tracing
      @available = {}	# Hash of available trace keys, accumulated during the run
      @delayed = nil	# A delayed message, emitted only if the enclosed block emits tracing

      @keys = {}
      if (e = ENV["TRACE"])
	e.split(/[^_a-zA-Z0-9]/).each{|k| enable(k) }
      end
    end

    def trace(*args, &block)
      begin
	old_indent, old_nested, old_delayed, enabled = @indent, @nested, @delayed, show(*args)
	# This monstrosity reduces the steps when single-stepping:
	block ? yield : (args.size == 0 ? self : enabled)
      ensure
	@indent, @nested, @delayed = old_indent, old_nested, old_delayed
      end
    end

    def available_keys
      @available.keys
    end

    def enabled? key
      !key.empty? && @keys[key.to_sym]
    end

    def enable key
      if !key.empty? && !@keys[s = key.to_sym]
	@keys[s] = true
	setup_help if s == :help
	setup_flame if s == :flame
      else
	true
      end
    end

    def disable key
      !key.empty? and @keys.delete(key.to_sym)
    end

    def toggle key
      if !key.empty?
	if enabled?(key)
	  disable(key)
	  false
	else
	  enable(key)
	  true
	end
      end
    end

    def setup_help
      at_exit {
	$stderr.puts "---\nTracing keys available: #{@available.keys.map{|s| s.to_s}.sort*", "}"
      }
    end

    def setup_flame
      require 'ruby-prof'
      require 'ruby-prof-flamegraph'
      profile_result = RubyProf.start
      at_exit {
	profile_result2 = RubyProf.stop
	printer = RubyProf::FlameGraphPrinter.new(profile_result2)
	data_file = "/tmp/flamedata_#{Process.pid}.txt"
	svg_file = "/tmp/flamedata_#{Process.pid}.svg"
	flamegraph = File.dirname(__FILE__)+"/flamegraph.pl"
	File.popen("tee #{data_file} | perl #{flamegraph} --countname=ms --width=4800 > #{svg_file}", "w") { |f|
	  printer.print(f, {})
	}
	STDERR.puts("Flame graph dumped to file:///#{svg_file}")
      }
    end

    def setup_debugger
      begin
	require 'ruby-trace '
	Debugger.start # (:post_mortem => true)  # Some Ruby versions crash on post-mortem debugging
      rescue LoadError
	# Ok, no debugger, tough luck.
      end

      if trace :trap
	trap('SIGINT') do
	  puts "Stopped at:\n\t"+caller*"\n\t"
	  debugger
	  true	# Stopped on SIGINT
	end
      end

      errors = []
      (
	[ENV["DEBUG_PREFERENCE"]].compact +
	[
	  'byebug',
	  'pry',
	  'debugger',
	  'ruby-trace '
	]
      ).each do |debugger|
	begin
	  require debugger
	  if debugger == 'byebug'
	    Kernel.class_eval do
	      alias_method :debugger, :byebug
	    end
	  end
	  ::Debugger.start if (const_get(::Debugger) rescue nil)
	  return
	rescue LoadError => e
	  errors << e
	end
      end

      # Report when we couldn't load any debugger
      $stderr.p errors
    end

    def setup_firstaid
      if trace :firstaid
	puts "Preparing first aid kit"
	::Exception.class_eval do
	  alias_method :firstaid_initialize, :initialize

	  def initialize *args, &b
	    send(:firstaid_initialize, *args, &b)
	    return if NoMethodError === self && message =~ /^undefined method `to_ary' for \#<Gem::Specification/
	    return if LoadError == self
	    puts "Stopped due to #{self.class}: #{message} at "+caller*"\n\t"
	    debugger
	    true # Stopped in Exception constructor
	  end
	end
      end
    end

  private
    def show(*args)
      enabled_prefix = selected?(args)

      # Emit the message if enabled or a parent is:
      if enabled_prefix && args.size > 0
	message =
	  "\##{enabled_prefix} " +
	  '  '*@indent +
	  args.
	    map{|a| a.respond_to?(:call) ? a.call : a}.
	    join(' ')

	if @delayed == true
	  @delayed = message	# Arrange to display this message later, if necessary
	elsif @delayed
	  puts @delayed		# Display a delayed message, then the current one
	  @delayed = nil
	  puts message
	else
	  puts message
	end
      end
      @indent += (enabled_prefix ? 1 : 0)
      !!enabled_prefix
    end

    def selected?(args)
      # Figure out whether this trace is enabled (itself or by :all), if it nests, and if we should print the key:
      key =
	if Symbol === args[0]
	  control = args.shift
	  case s = control.to_s
	  when /_\Z/		# Enable all nested trace calls
	    nested = true
	    s.sub(/_\Z/, '').to_sym
	  when /\?\Z/		# Delay this message until a nested active trace
	    @delayed = true
	    s.sub(/\?\Z/, '').to_sym
	  else
	    control
	  end
	else
	  :all
	end

      @available[key] ||= key		# Remember that this trace was requested, for help
      @nested ||= nested		# Activate nesting, if requested
      if @nested ||			# This trace is enabled because it's in a nested block
	  @keys[key] ||			# This trace is enabled in its own right
	  @keys[:all]			# This trace is enabled because all are
	if @keys[:keys] || @keys[:all]	# Use a formatting prefix?
	  enabled_prefix = " %-15s"%key
	  @keys[key] = enabled_prefix if @keys[key] == true # Save the formatting prefix
	else
	  enabled_prefix = ''
	end
      end

      enabled_prefix
    end

  end
end

# Make the trace method globally available:
class Object
  def trace *args, &block
    (ActiveFacts.tracer ||= ActiveFacts::Tracer.new).trace(*args, &block)
  end
end

# Load the ruby debugger before everything else, if requested
if trace(:debug) or trace(:firstaid) or trace(:trap)
  trace.setup_debugger
  trace.setup_firstaid
end
