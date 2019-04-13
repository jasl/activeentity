# frozen_string_literal: true

module ActiveEntity
  # Returns the version of the currently loaded Active Entity as a <tt>Gem::Version</tt>
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 0
    MINOR = 0
    TINY  = 1
    PRE   = "beta3"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
