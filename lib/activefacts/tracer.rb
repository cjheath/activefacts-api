#
#       ActiveFacts Support code.
#       The trace method supports indented tracing.
#       Set the TRACE environment variable to enable it. Search the code to find the TRACE keywords, or use "all".
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  (class << self; self; end).class_eval do
    attr_accessor :tracer
  end

  class Tracer
    def initialize
      @nested = false   # Set when a block enables all enclosed tracing
      @available = {}

      # First time, initialise the tracing environment
      @indent = 0
      @keys = {}
      if (e = ENV[@@trace_name ||= "TRACE"])
        e.split(/[^_a-zA-Z0-9]/).each{|k| enable(k) }
        if @keys[:help]
          at_exit {
            @stderr.puts "---\nDebugging keys available: #{@available.keys.map{|s| s.to_s}.sort*", "}"
          }
        end
        if @keys[:debug]
          errors = []
          success = false
          (
	    [ENV["DEBUG_PREFERENCE"]].compact +
	    [
	      'byebug',
	      'pry',
	      'debugger',
	      'ruby-debug'
	    ]
	  ).each do |debugger|
            begin
              require debugger
              puts "Loaded "+debugger
	      if debugger == 'byebug'
		Kernel.class_eval do
		  alias_method :byebug, :debugger
		end
	      end
              success = true
              break
            rescue LoadError => e
              errors << e
            end
          end
          unless success
            puts "Can't load any debugger, failed on:\n#{errors.inspect}"
          end
          ::Debugger.start rescue nil
        end
      end
    end

    def keys
      @available.keys
    end

    def enabled key
      !key.empty? && @keys[key.to_sym]
    end

    def enable key
      !key.to_s.empty? && @keys[key.to_sym] = true
    end

    def disable key
      !key.to_s.empty? && @keys.delete(key.to_sym)
    end

    def toggle key
      !key.to_s.empty? and enabled(key) ? (disable(key); false) : (enable(key); true)
    end

    def selected(args)
      # Figure out whether this trace is enabled (itself or by :all), if it nests, and if we should print the key:
      key =
        if Symbol === args[0]
          control = args.shift
          if (s = control.to_s) =~ /_\Z/
            nested = true
            s.sub(/_\Z/, '').to_sym     # Avoid creating new strings willy-nilly
          else
            control
          end
        else
          :all
        end

      @available[key] ||= key   # Remember that this trace was requested, for help
      enabled = @nested ||      # This trace is enabled because it's in a nested block
                @keys[key] ||   # This trace is enabled in its own right
                @keys[:all]     # This trace is enabled because all are
      @nested = nested
      [
        (enabled ? 1 : 0),
        @keys[:all] ? " %-15s"%control : nil
      ]
    end

    def show(*args)
      enabled, key_to_show = selected(args)

      # Emit the message if enabled or a parent is:
      if args.size > 0 && enabled == 1
        puts "\##{key_to_show} " +
          '  '*@indent +
          args.
#            A laudable aim, certainly, but in practise the Procs leak and slow things down:
#            map{|a| a.respond_to?(:call) ? a.call : a}.
            join(' ')
      end
      @indent += enabled
      enabled
    end

    def trace(*args, &block)
      begin
        old_indent, old_nested, enabled  = @indent, @nested, show(*args)
        return (block || proc { enabled == 1 }).call
      ensure
        @indent, @nested = old_indent, old_nested
      end
    end
  end
end

class Object
  def trace *args, &block
    (ActiveFacts.tracer ||= ActiveFacts::Tracer.new).trace(*args, &block)
  end
end

trace ''
