# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  include GitSandbox

  def test_unknown_command_exits_1
    ex = nil
    capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["bogus"]) } }
    assert_equal 1, ex.status
  end

  def test_create_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["create"]) } }
  end

  def test_stack_dispatches
    capture_io { GT::CLI.run(["stack"]) }
  end

  def test_land_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["land"]) } }
  end

  def test_git_error_exits_2
    GT::State.stub(:new, -> { raise GT::GitError, "broken" }) do
      ex = nil
      capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["stack"]) } }
      assert_equal 2, ex.status
    end
  end

  def test_restack_blocked_when_state_active
    GT::State.new.save(branches: ["feature"], index: 0)
    ex = nil
    capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["stack"]) } }
    assert_equal 1, ex.status
  end

  def test_restack_allowed_when_state_active
    GT::State.new.save(branches: ["feature"], index: 0)
    capture_io { GT::CLI.run(["restack"]) }
  end

  def test_help_flag
    out, = capture_io { GT::CLI.run(["--help"]) }
    assert_match "Usage", out
  end

  def test_no_args_shows_usage
    out, = capture_io { GT::CLI.run([]) }
    assert_match "Usage", out
  end
end
