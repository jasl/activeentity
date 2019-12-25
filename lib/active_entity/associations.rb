# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/conversions"
require "active_support/core_ext/module/remove_method"
require "active_entity/errors"

module ActiveEntity
  class AssociationNotFoundError < ConfigurationError #:nodoc:
    def initialize(record = nil, association_name = nil)
      if record && association_name
        super("Association named '#{association_name}' was not found on #{record.class.name}; perhaps you misspelled it?")
      else
        super("Association was not found.")
      end
    end
  end

  class InverseOfAssociationNotFoundError < ActiveEntityError #:nodoc:
    def initialize(reflection = nil, associated_class = nil)
      if reflection
        super("Could not find the inverse association for #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{associated_class.nil? ? reflection.class_name : associated_class.name})")
      else
        super("Could not find the inverse association.")
      end
    end
  end

  # See ActiveEntity::Associations::ClassMethods for documentation.
  module Associations # :nodoc:
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    # These classes will be loaded when associations are created.
    # So there is no need to eager load them.
    module Embedded
      extend ActiveSupport::Autoload

      autoload :Association, "active_entity/associations/embedded/association"
      autoload :SingularAssociation, "active_entity/associations/embedded/singular_association"
      autoload :CollectionAssociation, "active_entity/associations/embedded/collection_association"
      autoload :CollectionProxy, "active_entity/associations/embedded/collection_proxy"

      module Builder #:nodoc:
        autoload :Association,             "active_entity/associations/embedded/builder/association"
        autoload :SingularAssociation,     "active_entity/associations/embedded/builder/singular_association"
        autoload :CollectionAssociation,   "active_entity/associations/embedded/builder/collection_association"

        autoload :EmbeddedIn,              "active_entity/associations/embedded/builder/embedded_in"
        autoload :EmbedsOne,               "active_entity/associations/embedded/builder/embeds_one"
        autoload :EmbedsMany,              "active_entity/associations/embedded/builder/embeds_many"
      end

      eager_autoload do
        autoload :EmbeddedInAssociation
        autoload :EmbedsOneAssociation
        autoload :EmbedsManyAssociation
      end
    end

    def self.eager_load!
      super
      Embedded.eager_load!
    end

    # Returns the association instance for the given name, instantiating it if it doesn't already exist
    def association(name) #:nodoc:
      association = association_instance_get(name)

      if association.nil?
        unless reflection = self.class._reflect_on_association(name)
          raise AssociationNotFoundError.new(self, name)
        end
        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    def association_cached?(name) # :nodoc:
      @association_cache.key?(name)
    end

    def initialize_dup(*) # :nodoc:
      @association_cache = {}
      super
    end

    private

      # Clears out the association cache.
      def clear_association_cache
        @association_cache.clear if persisted?
      end

      def init_internals
        @association_cache = {}
        super
      end

      # Returns the specified association instance if it exists, +nil+ otherwise.
      def association_instance_get(name)
        @association_cache[name]
      end

      # Set the specified association instance.
      def association_instance_set(name, association)
        @association_cache[name] = association
      end

      module ClassMethods
        def embedded_in(name, **options)
          reflection = Embedded::Builder::EmbeddedIn.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end

        def embeds_one(name, **options)
          reflection = Embedded::Builder::EmbedsOne.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end

        def embeds_many(name, **options)
          reflection = Embedded::Builder::EmbedsMany.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end

        def association_names
          @association_names ||=
            if !abstract_class?
              reflections.keys.map(&:to_sym)
            else
              []
            end
        end

        def embedded_association_names
          @association_names ||=
            if !abstract_class?
              reflections.select { |_, r| r.embedded? }.keys.map(&:to_sym)
            else
              []
            end
        end
      end
  end
end
