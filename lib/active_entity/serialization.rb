# frozen_string_literal: true

module ActiveEntity #:nodoc:
  # = Active Entity \Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = false
    end

    def serializable_hash(include_embedded: true, **options)
      if include_embedded
        include = Array.wrap(options[:include]).concat(self.class.embedded_association_names)
        options[:include] = include
      end

      # options[:except] = Array(options[:except]).map(&:to_s)
      # options[:except] |= Array(self.class.inheritance_attribute)

      super(options)
    end
  end
end
