# frozen_string_literal: true

require "test_helper"

class UITest < Minitest::Test
  def test_confirm_delegates_to_cli_ui
    ::CLI::UI.stub(:confirm, true) do
      assert GT::UI.confirm("Are you sure?")
    end
  end

  def test_confirm_false_delegates_to_cli_ui
    ::CLI::UI.stub(:confirm, false) do
      refute GT::UI.confirm("Are you sure?")
    end
  end

  def test_prompt_select_delegates_to_cli_ui
    ::CLI::UI.stub(:ask, "feature") do
      assert_equal "feature", GT::UI.prompt_select("Pick:", ["main", "feature"])
    end
  end

  def test_spinner_in_non_tty_yields_block
    called = false
    GT::UI.spinner("Testing") { called = true }
    assert called
  end

  def test_spinner_returns_block_result
    result = GT::UI.spinner("Testing") { 42 }
    assert_equal 42, result
  end

  def test_spinner_uses_spin_group_in_tty
    invoked = false
    fake_sg = Object.new
    fake_sg.define_singleton_method(:add) { |_title, &blk| blk.call }

    ::CLI::UI::SpinGroup.stub(:new, ->(**_opts, &blk) { invoked = true; blk.call(fake_sg) }) do
      $stdout.stub(:tty?, true) do
        GT::UI.spinner("TTY spinner") {}
      end
    end
    assert invoked
  end

  def test_spinner_propagates_exceptions_in_tty
    fake_sg = Object.new
    fake_sg.define_singleton_method(:add) { |_title, &blk| blk.call rescue nil }

    ::CLI::UI::SpinGroup.stub(:new, ->(**_opts, &blk) { blk.call(fake_sg) }) do
      $stdout.stub(:tty?, true) do
        assert_raises(RuntimeError) do
          GT::UI.spinner("Failing spinner") { raise "boom" }
        end
      end
    end
  end
end
