# frozen_string_literal: true

module ActiveEntity
  # This module exists because ActiveEntity::AttributeMethods::Dirty needs to
  # define callbacks, but continue to have its version of +save+ be the super
  # method of ActiveEntity::Callbacks. This will be removed when the removal
  # of deprecated code removes this need.
  module DefineCallbacks
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      include ActiveModel::Callbacks
    end

    included do
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :initialize, only: :after
    end
  end
end
