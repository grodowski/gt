# frozen_string_literal: true

require "test_helper"

class StateTest < Minitest::Test
  include GitSandbox

  def setup
    super
    @state = GT::State.new
  end

  def test_inactive_by_default
    refute @state.active?
  end

  def test_save_and_load
    @state.save(branches: %w[feature child], index: 0)
    assert @state.active?
    data = @state.load
    assert_equal ["feature", "child"], data[:branches]
    assert_equal 0, data[:index]
  end

  def test_clear
    @state.save(branches: ["feature"], index: 0)
    @state.clear
    refute @state.active?
    assert_nil @state.load
  end

  def test_load_returns_nil_when_inactive
    assert_nil @state.load
  end

  def test_clear_is_noop_when_inactive
    @state.clear # should not raise
    refute @state.active?
  end
end
