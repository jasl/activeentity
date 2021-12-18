# frozen_string_literal: true

require "test_helper"

class ActiveEntityTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert ActiveEntity::VERSION
  end
end
