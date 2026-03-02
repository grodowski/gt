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
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::CLI.run(["restack"]) }
    end
  end

  def test_amend_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["amend"]) } }
  end

  def test_sync_dispatches
    GT::GitHub.stub(:pr_merged?, false) do
      GT::Git.stub(:pull, nil) do
        capture_io { GT::CLI.run(["sync"]) }
      end
    end
  end

  def test_edit_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["edit"]) } }
  end

  def test_up_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["up"]) } }
  end

  def test_down_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["down"]) } }
  end

  def test_top_dispatches
    out, = capture_io { GT::CLI.run(["top"]) }
    assert_match "Already at the top", out
  end

  def test_switch_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["switch"]) } }
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
