# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActiveEntity
  module AttributeMethods
    module Dirty
      extend ActiveSupport::Concern

      include ActiveModel::Dirty
    end
  end
end
