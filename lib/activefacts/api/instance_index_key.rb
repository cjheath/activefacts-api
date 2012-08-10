class InstanceIndexKey
  attr_reader :hash

  def initialize(hash)
    @hash = flatten_key(hash)
  end

  def <=>(other)
    result = @hash <=> other.hash
    if result.nil?
      @hash.to_s <=> other.hash.to_s
    else
      result
    end
  end

  def to_hash
    @hash
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
