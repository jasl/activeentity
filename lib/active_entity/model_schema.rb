# frozen_string_literal: true

require "monitor"

module ActiveEntity
  module ModelSchema
    extend ActiveSupport::Concern

    included do
      delegate :type_for_attribute, to: :class

      self.inheritance_attribute = "type"

      initialize_load_schema_monitor
    end

    module ClassMethods
      def inheritance_attribute
        (@inheritance_attribute ||= nil) || superclass.inheritance_attribute
      end

      # Sets the value of inheritance_attribute
      def inheritance_attribute=(value)
        @inheritance_attribute = value.to_s
        @explicit_inheritance_attribute = true
      end

      def attributes_builder # :nodoc:
        unless defined?(@attributes_builder) && @attributes_builder
          defaults = _default_attributes
          @attributes_builder = ActiveModel::AttributeSet::Builder.new(attribute_types, defaults)
        end
        @attributes_builder
      end

      def attribute_types # :nodoc:
        load_schema
        @attribute_types ||= Hash.new(Type.default_value)
      end

      def yaml_encoder # :nodoc:
        @yaml_encoder ||= ActiveModel::AttributeSet::YAMLEncoder.new(attribute_types)
      end

      # Returns the type of the attribute with the given name, after applying
      # all modifiers. This method is the only valid source of information for
      # anything related to the types of a model's attributes. This method will
      # access the database and load the model's schema if it is required.
      #
      # The return value of this method will implement the interface described
      # by ActiveModel::Type::Value (though the object itself may not subclass
      # it).
      #
      # +attr_name+ The name of the attribute to retrieve the type for. Must be
      # a string or a symbol.
      def type_for_attribute(attr_name, &block)
        attr_name = attr_name.to_s
        if block
          attribute_types.fetch(attr_name, &block)
        else
          attribute_types[attr_name]
        end
      end

      def _default_attributes # :nodoc:
        load_schema
        @default_attributes ||= ActiveModel::AttributeSet.new({})
      end

      protected

        def initialize_load_schema_monitor
          @load_schema_monitor = Monitor.new
        end

      private

        def inherited(child_class)
          super
          child_class.initialize_load_schema_monitor
        end

        def schema_loaded?
          defined?(@schema_loaded) && @schema_loaded
        end

        def load_schema
          return if schema_loaded?
          @load_schema_monitor.synchronize do
            return if defined?(@load_schema_invoked) && @load_schema_invoked

            load_schema!
            @schema_loaded = true
          end
        end

        def load_schema!
          @load_schema_invoked = true
        end

        def reload_schema_from_cache
          @attribute_types = nil
          @default_attributes = nil
          @attributes_builder = nil
          @schema_loaded = false
          @load_schema_invoked = false
          @attribute_names = nil
          @yaml_encoder = nil
          direct_descendants.each do |descendant|
            descendant.send(:reload_schema_from_cache)
          end
        end
    end
  end
end
