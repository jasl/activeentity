# frozen_string_literal: true

module ActiveEntity
  module ReadonlyAttributes
    extend ActiveSupport::Concern

    included do
      class_attribute :_attr_readonly, instance_accessor: false, default: []
    end

    def disable_readonly!
      @_readonly_enabled = false
    end

    def enable_readonly!
      @_readonly_enabled = true
    end

    def enable_readonly
      return unless block_given?

      disable_readonly!
      yield self
      enable_readonly!

      self
    end

    def _readonly_enabled
      @_readonly_enabled
    end
    alias readonly_enabled? _readonly_enabled

    module ClassMethods
      # Attributes listed as readonly will be used to create a new record but update operations will
      # ignore these fields.
      def attr_readonly(*attributes)
        self._attr_readonly = Set.new(attributes.map(&:to_s)) + (_attr_readonly || [])
      end

      # Returns an array of all the attributes that have been specified as readonly.
      def readonly_attributes
        _attr_readonly
      end
    end
  end
end
