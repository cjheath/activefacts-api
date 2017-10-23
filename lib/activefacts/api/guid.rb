require 'delegate'
require 'securerandom'

module SecureRandom
  def self.format_uuid hex32
    hex32.sub(
      @@format_pattern ||= /(........)(....)(....)(....)(............)/,
      @@format_string ||= '\1-\2-\3-\4-\5'
    )
  end
end

unless defined? SecureRandom.uuid
  # I think this only applies to 1.8.6 (and JRuby/Rubinius in 1.8 mode) now:
  def SecureRandom.uuid
    format_uuid(hex(16))
  end
end

# The Guid class is what it says on the packet, but you can assert a :new one.
class Guid
  SEQ_FILE_NAME = "/tmp/ActiveFactsRandom"
  @@sequence = nil
  def initialize(i = :new)
    @@sequence = ENV['ACTIVEFACTS_RANDOM'] || false if @@sequence == nil
    if i == :new
      case @@sequence
      when 'fixed'
        @@counter ||= 0
        @value = SecureRandom.format_uuid('%032x' % (@@counter += 1))
      when 'record'
        @@sequence_file ||= File.open(SEQ_FILE_NAME, 'w')
        @value = SecureRandom.uuid.freeze
        @@sequence_file.puts(@value)
      when 'replay'
        @@sequence_file ||= File.open(SEQ_FILE_NAME, 'r')
        @value = @@sequence_file.gets.chomp
      else
        @value = SecureRandom.uuid.freeze
      end
    elsif (v = i.to_s).length == 36 and !(v !~ /[^0-9a-f]/i)
      @value = v.clone.freeze
    else
      raise ArgumentError.new("Illegal non-Guid value #{i.inspect} given for Guid")
    end
  end

  def to_s
    @value
  end

  # if the value is unassigned, it equal?(:new).
  def equal? value
    @value == value
  end

  def == value
    @value == value.to_s
  end

  def inspect
    "\#<Guid #{@value}>"
  end

  def hash                              #:nodoc:
    @value.hash
  end

  def eql?(o)                           #:nodoc:
    to_s.eql?(o.to_s)
  end

  def <=>(o)                            #:nodoc:
    to_s.<=>(o.to_s)
  end

end
