# frozen_string_literal: true

module ActiveEntity
  module Type
    class UnsignedInteger < ActiveModel::Type::Integer # :nodoc:
      private

        def max_value
          ::Float::INFINITY
        end

        def min_value
          0
        end
    end
  end
end
