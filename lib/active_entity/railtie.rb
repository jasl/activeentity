# frozen_string_literal: true

require "active_entity"
require "rails"
require "active_support/core_ext/object/try"
require "active_model/railtie"

# For now, action_controller must always be present with
# Rails, so let's make sure that it gets required before
# here. This is needed for correctly setting up the middleware.
# In the future, this might become an optional require.
require "action_controller/railtie"

module ActiveEntity
  # = Active Entity Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.active_entity = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveEntity

    # When loading console, force ActiveEntity::Base to be loaded
    # to avoid cross references when loading a constant for the
    # first time. Also, make it output to STDERR.
    console do |_app|
      require "active_entity/base"
      unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDERR, STDOUT)
        console = ActiveSupport::Logger.new(STDERR)
        console.level = Rails.logger.level
        Rails.logger.extend ActiveSupport::Logger.broadcast console
      end
    end

    runner do
      require "active_entity/base"
    end

    initializer "active_entity.initialize_timezone" do
      ActiveSupport.on_load(:active_entity) do
        self.time_zone_aware_attributes = true
      end
    end

    initializer "active_entity.logger" do
      ActiveSupport.on_load(:active_entity) { self.logger ||= ::Rails.logger }
    end

    initializer "Check for cache versioning support" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:active_entity) do
          if app.config.active_entity.cache_versioning && Rails.cache
            unless Rails.cache.class.try(:supports_cache_versioning?)
              raise <<-end_error

You're using a cache store that doesn't support native cache versioning.
Your best option is to upgrade to a newer version of #{Rails.cache.class}
that supports cache versioning (#{Rails.cache.class}.supports_cache_versioning? #=> true).

Next best, switch to a different cache store that does support cache versioning:
https://guides.rubyonrails.org/caching_with_rails.html#cache-stores.

To keep using the current cache store, you can turn off cache versioning entirely:

    config.active_entity.cache_versioning = false

              end_error
            end
          end
        end
      end
    end

    initializer "active_entity.set_configs" do |app|
      configs = app.config.active_entity

      config.after_initialize do
        configs.each do |k, v|
          setter = "#{k}="
          if ActiveEntity.respond_to?(setter)
            ActiveEntity.send(setter, v)
          end
        end
      end

      ActiveSupport.on_load(:active_entity) do
        configs.each do |k, v|
          setter = "#{k}="
          # Some existing initializers might rely on Active Entity configuration
          # being copied from the config object to their actual destination when
          # `ActiveEntity::Base` is loaded.
          # So to preserve backward compatibility we copy the config a second time.
          if ActiveEntity.respond_to?(setter)
            ActiveEntity.send(setter, v)
          else
            send(setter, v)
          end
        end
      end
    end


    initializer "active_entity.set_filter_attributes" do
      ActiveSupport.on_load(:active_entity) do
        self.filter_attributes += Rails.application.config.filter_parameters
      end
    end
  end
end
