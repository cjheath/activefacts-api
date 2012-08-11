class InstanceIndexKey
  attr_reader :value

  def initialize(hash)
    @value = flatten_key(hash)
  end

  def <=>(other)
    if contains_nil?(@value) || contains_nil?(other.value)
      @value.inspect <=> other.value.inspect
    else
      @value <=> other.value
    end
  end

  def contains_nil?(arr)
    if arr.class.ancestors.include?(Array)
      arr.any? do |el|
        if el.nil?
          true
        else
          contains_nil?(el)
        end
      end
    else
      arr.nil?
    end
  end

  def ==(other)
    @value == other.value
  end

  def eql?(other)
    if self.class == other.class
      self == other
    else
      false
    end
  end

  def hash
    @value.hash
  end

  private
  def flatten_key(key)
    if key.is_a?(Array)
      key.map { |identifier| flatten_key(identifier) }
    elsif key.respond_to?(:identifying_role_values)
      key.identifying_role_values
    else
      key
    end
  end
end