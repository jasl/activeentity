# frozen_string_literal: true

require "active_support"
require "active_support/rails"
require "yaml"

require "active_model"
require "active_model/attribute_set"

require "active_entity/version"

module ActiveEntity
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Core
  autoload :Enum
  autoload :Inheritance
  autoload :Integration
  autoload :ModelSchema
  autoload :NestedAttributes
  autoload :ReadonlyAttributes
  autoload :Reflection
  autoload :Serialization
  autoload :Store
  autoload :Translation
  autoload :Validations

  eager_autoload do
    autoload :ActiveEntityError, "active_entity/errors"

    autoload :Aggregations
    autoload :Associations
    autoload :AttributeAssignment
    autoload :AttributeMethods
    autoload :ValidateEmbeddedAssociation

    autoload :Type
  end

  module Coders
    autoload :YAMLColumn, "active_entity/coders/yaml_column"
    autoload :JSON, "active_entity/coders/json"
  end

  module AttributeMethods
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :BeforeTypeCast
      autoload :PrimaryKey
      autoload :Query
      autoload :Serialization
      autoload :Read
      autoload :TimeZoneConversion
      autoload :Write
    end
  end

  def self.eager_load!
    super

    ActiveEntity::Associations.eager_load!
    ActiveEntity::AttributeMethods.eager_load!
  end
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path("active_entity/locale/en.yml", __dir__)
end

YAML.load_tags["!ruby/object:ActiveEntity::AttributeSet"] = "ActiveModel::AttributeSet"
YAML.load_tags["!ruby/object:ActiveEntity::LazyAttributeHash"] = "ActiveModel::LazyAttributeHash"
