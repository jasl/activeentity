# frozen_string_literal: true

module ActiveEntity
  module LegacyYamlAdapter # :nodoc:
    def self.convert(coder)
      return coder unless coder.is_a?(Psych::Coder)

      case coder["active_entity_yaml_version"]
      when 1, 2 then coder
      else
        raise("Active Entity doesn't know how to load YAML with this format.")
      end
    end
  end
end
