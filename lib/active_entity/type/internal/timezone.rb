# frozen_string_literal: true

module ActiveEntity
  module Type
    module Internal
      module Timezone
        def is_utc?
          ActiveEntity.default_timezone == :utc
        end

        def default_timezone
          ActiveEntity.default_timezone
        end
      end
    end
  end
end
