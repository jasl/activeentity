# frozen_string_literal: true

require "active_model/type"

require "active_entity/type/internal/timezone"

require "active_entity/type/date"
require "active_entity/type/date_time"
require "active_entity/type/decimal_without_scale"
require "active_entity/type/json"
require "active_entity/type/time"
require "active_entity/type/text"
require "active_entity/type/unsigned_integer"

require "active_entity/type/modifiers/array"

require "active_entity/type/serialized"
require "active_entity/type/registry"

require "active_entity/type/type_map"
require "active_entity/type/hash_lookup_type_map"

module ActiveEntity
  module Type
    @registry = ActiveEntity::Type::Registry.new

    class << self
      attr_accessor :registry # :nodoc:
      delegate :add_modifier, to: :registry

      # Add a new type to the registry, allowing it to be referenced as a
      # symbol by {ActiveEntity::Base.attribute}[rdoc-ref:Attributes::ClassMethods#attribute].
      # <tt>override: true</tt> will cause your type to be used instead of the native type.
      # <tt>override: false</tt> will cause the native type to be used over yours if one exists.
      def register(type_name, klass = nil, **options, &block)
        registry.register(type_name, klass, **options, &block)
      end

      def lookup(*args, **kwargs) # :nodoc:
        registry.lookup(*args, **kwargs)
      end

      def default_value # :nodoc:
        @default_value ||= Value.new
      end
    end

    Helpers = ActiveModel::Type::Helpers
    BigInteger = ActiveModel::Type::BigInteger
    Binary = ActiveModel::Type::Binary
    Boolean = ActiveModel::Type::Boolean
    Decimal = ActiveModel::Type::Decimal
    Float = ActiveModel::Type::Float
    Integer = ActiveModel::Type::Integer
    String = ActiveModel::Type::String
    Value = ActiveModel::Type::Value

    add_modifier({ array: true }, Modifiers::Array)

    register(:big_integer, Type::BigInteger, override: false)
    register(:binary, Type::Binary, override: false)
    register(:boolean, Type::Boolean, override: false)
    register(:date, Type::Date, override: false)
    register(:datetime, Type::DateTime, override: false)
    register(:decimal, Type::Decimal, override: false)
    register(:float, Type::Float, override: false)
    register(:integer, Type::Integer, override: false)
    register(:json, Type::Json, override: false)
    register(:string, Type::String, override: false)
    register(:text, Type::Text, override: false)
    register(:time, Type::Time, override: false)
  end
end
