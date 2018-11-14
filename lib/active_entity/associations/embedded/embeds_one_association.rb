# frozen_string_literal: true

module ActiveEntity
  module Associations
    module Embedded
      # = Active Entity Has One Association
      class EmbedsOneAssociation < SingularAssociation #:nodoc:
        private
          def replace(record)
            raise_on_type_mismatch!(record) if record

            return target unless record

            self.target = record
          end
      end
    end
  end
end
