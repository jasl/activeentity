# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActiveEntity
  module AttributeMethods
    module Dirty
      extend ActiveSupport::Concern

      include ActiveModel::Dirty

      included do
        if self < ::ActiveEntity::Timestamp
          raise "You cannot include Dirty after Timestamp"
        end
      end
    end
  end
end
