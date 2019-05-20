# frozen_string_literal: true

require "active_entity"
require "rails"
require "active_model/railtie"

module ActiveEntity
  # = Active Entity Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.eager_load_namespaces << ActiveEntity

    runner do
      require "active_record/base"
    end
  end
end
