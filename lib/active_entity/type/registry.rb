# frozen_string_literal: true

require "active_model/type/registry"

module ActiveEntity
  # :stopdoc:
  module Type
    class Registry < ActiveModel::Type::Registry
      def add_modifier(options, klass, **args)
        registrations << DecorationRegistration.new(options, klass, **args)
      end

      private

        def registration_klass
          Registration
        end

        def find_registration(symbol, *args, **kwargs)
          registrations
            .select { |registration| registration.matches?(symbol, *args, **kwargs) }
            .max
        end
    end

    class Registration
      def initialize(name, block, override: nil)
        @name = name
        @block = block
        @override = override
      end

      def call(_registry, *args, **kwargs)
        if kwargs.any? # https://bugs.ruby-lang.org/issues/10856
          block.call(*args, **kwargs)
        else
          block.call(*args)
        end
      end

      def matches?(type_name, *args, **kwargs)
        type_name == name
      end

      def <=>(other)
        priority <=> other.priority
      end

      protected

        attr_reader :name, :block, :override

        def priority
          override ? 1 : 0
        end
    end

    class DecorationRegistration < Registration
      def initialize(options, klass, **)
        @options = options
        @klass = klass
      end

      def call(registry, *args, **kwargs)
        subtype = registry.lookup(*args, **kwargs.except(*options.keys))
        klass.new(subtype)
      end

      def matches?(*args, **kwargs)
        matches_options?(**kwargs)
      end

      def priority
        super | 4
      end

      private

        attr_reader :options, :klass

        def matches_options?(**kwargs)
          options.all? do |key, value|
            kwargs[key] == value
          end
        end
    end
  end

  class TypeConflictError < StandardError
  end
  # :startdoc:
end
