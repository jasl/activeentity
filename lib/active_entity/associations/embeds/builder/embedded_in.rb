# frozen_string_literal: true

module ActiveEntity::Associations::Embeds::Builder # :nodoc:
  class EmbeddedIn < SingularAssociation # :nodoc:
    def self.macro
      :embedded_in
    end

    def self.valid_options(options)
      super + [:default]
    end

    def self.define_callbacks(model, reflection)
      super
      add_default_callbacks(model, reflection) if reflection.options[:default]
    end

    def self.add_default_callbacks(model, reflection)
      model.before_validation lambda { |o|
        o.association(reflection.name).default(&reflection.options[:default])
      }
    end

    def self.define_validations(model, reflection)
      if reflection.options.key?(:required)
        reflection.options[:optional] = !reflection.options.delete(:required)
      end

      required = !reflection.options[:optional]

      super

      if required
        model.validates_presence_of reflection.name, message: :required
      end
    end

    def self.define_change_tracking_methods(model, reflection)
      model.generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{reflection.name}_changed?
          association(:#{reflection.name}).target_changed?
        end
        def #{reflection.name}_previously_changed?
          association(:#{reflection.name}).target_previously_changed?
        end
      CODE
    end

    private_class_method :macro, :valid_options, :valid_dependent_options, :define_callbacks,
                         :define_validations, :define_change_tracking_methods,
                         :add_default_callbacks
  end
end
