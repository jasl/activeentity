# frozen_string_literal: true

module ActiveEntity
  module Associations
    module Embeds
      # = Active Entity Belongs To Association
      class EmbeddedInAssociation < SingularAssociation # :nodoc:
        def default(&block)
          writer(owner.instance_exec(&block)) if reader.nil?
        end

        private

          def replace(record)
            if record
              raise_on_type_mismatch!(record)
              set_inverse_instance(record)
            end

            self.target = record
          end

          def invertible_for?(record)
            inverse = inverse_reflection_for(record)
            inverse && (inverse.embeds_one? || inverse.klass.embeds_many_inversing)
          end
      end
    end
  end
end
