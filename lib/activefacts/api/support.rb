#
#       ActiveFacts Runtime API.
#       Various additions or patches to Ruby built-in classes, and some global support methods
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#

# Define Infinity as a constant, if it's not already defined:
# We use this to define open-ended ranges.
unless Object.const_defined?("Infinity")
  Infinity = 1.0/0.0
end

class String #:nodoc:
  # This may be overridden by a version from ActiveSupport. For our purposes, either will work.
  def camelcase(first_letter = :upper)
    if first_letter == :upper
      gsub(/(^|[_\s]+)([A-Za-z])/){ $2.upcase }
    else
      gsub(/([_\s]+)([A-Za-z])/){ $2.upcase }
    end
  end

  def snakecase
    gsub(/([^_])([A-Z][a-z])/,'\1_\2').downcase
  end

  def camelwords
    gsub(/-([a-zA-Z])/){ $1.upcase }.                 # Break and upcase on hyphenated words
      gsub(/([a-z])([A-Z])/,'\1_\2').
      split(/[_\s]+/)
  end
end

class Module #:nodoc:
  def modspace
    space = name[ 0...(name.rindex( '::' ) || 0)]
    space == '' ? Object : eval(space)
  end

  def basename
    name.gsub(/.*::/, '')
  end
end
