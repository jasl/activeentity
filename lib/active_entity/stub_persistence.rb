# frozen_string_literal: true

module ActiveEntity
  # = Active Entity \StubPersistence
  module StubPersistence
    extend ActiveSupport::Concern

    def new_record?
      true
    end

    def destroyed?
      false
    end

    def persisted?
      false
    end
  end
end
