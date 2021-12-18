# frozen_string_literal: true

require "active_support/core_ext/string/filters"

module ActiveEntity
  # = Active Entity Reflection
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_reflections, instance_writer: false, default: {}
      class_attribute :aggregate_reflections, instance_writer: false, default: {}
    end

    class << self
      def create(macro, name, scope, options, ae)
        reflection_class_for(macro).new(name, scope, options, ae)
      end

      def add_reflection(ae, name, reflection)
        ae.clear_reflections_cache
        name = -name.to_s
        ae._reflections = ae._reflections.except(name).merge!(name => reflection)
      end

      def add_aggregate_reflection(ae, name, reflection)
        ae.aggregate_reflections = ae.aggregate_reflections.merge(-name.to_s => reflection)
      end

      private

        def reflection_class_for(macro)
          case macro
          when :composed_of
            AggregateReflection
          when :embedded_in
            EmbeddedInReflection
          when :embeds_one
            EmbedsOneReflection
          when :embeds_many
            EmbedsManyReflection
          else
            raise "Unsupported Macro: #{macro}"
          end
        end
    end

    # \Reflection enables the ability to examine the associations and aggregations of
    # Active Entity classes and objects. This information, for example,
    # can be used in a form builder that takes an Active Entity object
    # and creates input fields for all of the attributes depending on their type
    # and displays the associations to other objects.
    #
    # MacroReflection class has info for AggregateReflection and AssociationReflection
    # classes.
    module ClassMethods
      # Returns an array of AggregateReflection objects for all the aggregations in the class.
      def reflect_on_all_aggregations
        aggregate_reflections.values
      end

      # Returns the AggregateReflection object for the named +aggregation+ (use the symbol).
      #
      #   Account.reflect_on_aggregation(:balance) # => the balance AggregateReflection
      #
      def reflect_on_aggregation(aggregation)
        aggregate_reflections[aggregation.to_s]
      end

      # Returns a Hash of name of the reflection as the key and an AssociationReflection as the value.
      #
      #   Account.reflections # => {"balance" => AggregateReflection}
      #
      def reflections
        @__reflections ||= begin
          ref = {}

          _reflections.each do |name, reflection|
            parent_reflection = reflection.parent_reflection

            if parent_reflection
              parent_name = parent_reflection.name
              ref[parent_name.to_s] = parent_reflection
            else
              ref[name] = reflection
            end
          end

          ref
        end
      end

      # Returns an array of AssociationReflection objects for all the
      # associations in the class. If you only want to reflect on a certain
      # association type, pass in the symbol (<tt>:has_many</tt>, <tt>:has_one</tt>,
      # <tt>:belongs_to</tt>) as the first parameter.
      #
      # Example:
      #
      #   Account.reflect_on_all_associations             # returns an array of all associations
      #   Account.reflect_on_all_associations(:has_many)  # returns an array of all has_many associations
      #
      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values
        association_reflections.select! { |reflection| reflection.macro == macro } if macro
        association_reflections
      end

      # Returns the AssociationReflection object for the +association+ (use the symbol).
      #
      #   Account.reflect_on_association(:owner)             # returns the owner AssociationReflection
      #   Invoice.reflect_on_association(:line_items).macro  # returns :has_many
      #
      def reflect_on_association(association)
        reflections[association.to_s]
      end

      def _reflect_on_association(association) # :nodoc:
        _reflections[association.to_s]
      end

      # Returns an array of AssociationReflection objects for all associations which have <tt>:autosave</tt> enabled.
      def reflect_on_all_autosave_associations
        reflections.values.select { |reflection| reflection.options[:autosave] }
      end

      def clear_reflections_cache # :nodoc:
        @__reflections = nil
      end
    end

    # Holds all the methods that are shared between MacroReflection and ThroughReflection.
    #
    #   AbstractReflection
    #     MacroReflection
    #       AggregateReflection
    #       AssociationReflection
    #         HasManyReflection
    #         HasOneReflection
    #         BelongsToReflection
    #         HasAndBelongsToManyReflection
    #     ThroughReflection
    #     PolymorphicReflection
    #     RuntimeReflection
    class AbstractReflection # :nodoc:
      def embedded?
        false
      end

      # Returns a new, unsaved instance of the associated class. +attributes+ will
      # be passed to the class's constructor.
      def build_association(attributes, &block)
        klass.new(attributes, &block)
      end

      # Returns the class name for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>'Money'</tt>
      # <tt>has_many :clients</tt> returns <tt>'Client'</tt>
      def class_name
        @class_name ||= -(options[:class_name] || derive_class_name).to_s
      end

      def inverse_of
        return unless inverse_name

        @inverse_of ||= klass._reflect_on_association inverse_name
      end

      def check_validity_of_inverse!
        if has_inverse? && inverse_of.nil?
          raise InverseOfAssociationNotFoundError.new(self)
        end
        if has_inverse? && inverse_of == self
          raise InverseOfAssociationRecursiveError.new(self)
        end
      end

      def alias_candidate(name)
        "#{plural_name}_#{name}"
      end

      protected

        def actual_source_reflection # FIXME: this is a horrible name
          self
        end

      private

        def ensure_option_not_given_as_class!(option_name)
          if options[option_name] && options[option_name].class == Class
            raise ArgumentError, "A class was passed to `:#{option_name}` but we are expecting a string."
          end
        end
    end

    # Base class for AggregateReflection and AssociationReflection. Objects of
    # AggregateReflection and AssociationReflection are returned by the Reflection::ClassMethods.
    class MacroReflection < AbstractReflection
      # Returns the name of the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>:balance</tt>
      # <tt>has_many :clients</tt> returns <tt>:clients</tt>
      attr_reader :name

      attr_reader :scope

      # Returns the hash of options used for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>{ class_name: "Money" }</tt>
      # <tt>has_many :clients</tt> returns <tt>{}</tt>
      attr_reader :options

      attr_reader :active_entity

      attr_reader :plural_name # :nodoc:

      def initialize(name, scope, options, active_entity)
        @name          = name
        @scope         = scope
        @options       = options
        @active_entity = active_entity
        @klass         = options[:anonymous_class]
        @plural_name   = name.to_s.pluralize
      end

      def autosave=(autosave)
        @options[:autosave] = autosave
        parent_reflection = self.parent_reflection
        if parent_reflection
          parent_reflection.autosave = autosave
        end
      end

      # Returns the class for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns the Money class
      # <tt>has_many :clients</tt> returns the Client class
      #
      #   class Company < ActiveEntity::Base
      #     has_many :clients
      #   end
      #
      #   Company.reflect_on_association(:clients).klass
      #   # => Client
      #
      # <b>Note:</b> Do not call +klass.new+ or +klass.create+ to instantiate
      # a new association object. Use +build_association+ or +create_association+
      # instead. This allows plugins to hook into association object creation.
      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        name.constantize
      end

      # Returns +true+ if +self+ and +other_aggregation+ have the same +name+ attribute, +active_entity+ attribute,
      # and +other_aggregation+ has an options hash assigned to it.
      def ==(other_aggregation)
        super ||
          other_aggregation.kind_of?(self.class) &&
          name == other_aggregation.name &&
          !other_aggregation.options.nil? &&
          active_entity == other_aggregation.active_entity
      end

      private

        def derive_class_name
          name.to_s.camelize
        end
    end

    # Holds all the metadata about an aggregation as it was specified in the
    # Active Entity class.
    class AggregateReflection < MacroReflection # :nodoc:
      def mapping
        mapping = options[:mapping] || [name, name]
        mapping.first.is_a?(Array) ? mapping : [mapping]
      end
    end

    # Holds all the metadata about an association as it was specified in the
    # Active Entity class.
    class EmbeddedAssociationReflection < MacroReflection # :nodoc:
      def compute_class(name)
        msg = <<-MSG.squish
          Rails couldn't find a valid model for #{name} association.
          Please provide the :class_name option on the association declaration.
          If :class_name is already provided, make sure it's an ActiveEntity::Base subclass.
        MSG

        begin
          klass = active_entity.send(:compute_type, name)

          unless klass < ActiveEntity::Base
            raise ArgumentError, msg
          end

          klass
        rescue NameError
          raise NameError, msg
        end
      end

      attr_reader :type, :foreign_type
      attr_accessor :parent_reflection # Reflection

      def initialize(name, scope, options, active_entity)
        super

        ensure_option_not_given_as_class!(:class_name)
      end

      def check_validity!
        check_validity_of_inverse!
      end

      def join_id_for(owner) # :nodoc:
        owner[join_foreign_key]
      end

      def through_reflection
        nil
      end

      def source_reflection
        self
      end

      def nested?
        false
      end

      def has_scope?
        false
      end

      def has_inverse?
        inverse_name
      end

      # Returns the macro type.
      #
      # <tt>has_many :clients</tt> returns <tt>:has_many</tt>
      def macro; raise NotImplementedError; end

      # Returns whether or not this association reflection is for a collection
      # association. Returns +true+ if the +macro+ is either +has_many+ or
      # +has_and_belongs_to_many+, +false+ otherwise.
      def collection?
        false
      end

      # Returns whether or not the association should be validated as part of
      # the parent's validation.
      #
      # Unless you explicitly disable validation with
      # <tt>validate: false</tt>, validation will take place when:
      #
      # * you explicitly enable validation; <tt>validate: true</tt>
      # * you use autosave; <tt>autosave: true</tt>
      # * the association is a +has_many+ association
      def validate?
        !!options[:validate]
      end

      # Returns +true+ if +self+ is a +embedded_in+ reflection.
      def embedded_in?; false; end

      # Returns +true+ if +self+ is a +embeds_one+ reflection.
      def embeds_one?; false; end

      def association_class; raise NotImplementedError; end

      def add_as_source(seed)
        seed
      end

      def extensions
        Array(options[:extend])
      end

      private

        # Attempts to find the inverse association name automatically.
        # If it cannot find a suitable inverse association name, it returns
        # +nil+.
        def inverse_name
          unless defined?(@inverse_name)
            @inverse_name = options.fetch(:inverse_of) { automatic_inverse_of }
          end

          @inverse_name
        end

        # returns either +nil+ or the inverse association name that it finds.
        def automatic_inverse_of
          if can_find_inverse_of_automatically?(self)
            inverse_name = ActiveSupport::Inflector.underscore(active_entity.name.demodulize).to_sym

            begin
              reflection = klass._reflect_on_association(inverse_name)
            rescue NameError
              # Give up: we couldn't compute the klass type so we won't be able
              # to find any associations either.
              reflection = false
            end

            if valid_inverse_reflection?(reflection)
              inverse_name
            end
          end
        end

        # Checks if the inverse reflection that is returned from the
        # +automatic_inverse_of+ method is a valid reflection. We must
        # make sure that the reflection's active_entity name matches up
        # with the current reflection's klass name.
        def valid_inverse_reflection?(reflection)
          reflection &&
            reflection != self &&
            klass <= reflection.active_entity &&
            can_find_inverse_of_automatically?(reflection, true)
        end

        # Checks to see if the reflection doesn't have any options that prevent
        # us from being able to guess the inverse automatically. First, the
        # <tt>inverse_of</tt> option cannot be set to false. Second, we must
        # have <tt>has_many</tt>, <tt>has_one</tt>, <tt>belongs_to</tt> associations.
        # Third, we must not have options such as <tt>:foreign_key</tt>
        # which prevent us from correctly guessing the inverse association.
        def can_find_inverse_of_automatically?(reflection, _inverse_reflection = false)
          reflection.options[:inverse_of] != false
        end

        def derive_class_name
          class_name = name.to_s
          class_name = class_name.singularize if collection?
          class_name.camelize
        end
    end

    class EmbedsManyReflection < EmbeddedAssociationReflection # :nodoc:
      def macro; :embeds_many; end

      def collection?; true; end

      def association_class
        Associations::Embeds::EmbedsManyAssociation
      end
    end

    class EmbedsOneReflection < EmbeddedAssociationReflection # :nodoc:
      def macro; :embeds_one; end

      def embeds_one?; true; end

      def association_class
        Associations::Embeds::EmbedsOneAssociation
      end
    end

    class EmbeddedInReflection < EmbeddedAssociationReflection # :nodoc:
      def macro; :embedded_in; end

      def embedded_in?; true; end

      def association_class
        Associations::Embeds::EmbeddedInAssociation
      end
    end
  end
end
