class InstanceIndexKey
  attr_reader :value

  def initialize(hash)
    @value = flatten_key(hash)
  end

  def <=>(other)
    result = @value <=> other.value
    if result.nil?
      @value.to_s <=> other.value.to_s
    else
      result
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
