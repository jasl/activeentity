# frozen_string_literal: true

require "test_helper"

class ActiveEntity::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, ActiveEntity
  end
end
