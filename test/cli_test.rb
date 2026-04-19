# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  include GitSandbox

  def test_gh_not_installed_exits_1
    GT::CLI.stub(:gh_installed?, false) do
      ex = nil
      capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["log"]) } }
      assert_equal 1, ex.status
    end
  end

  def test_gh_installed_returns_false_when_enoent
    Open3.stub(:capture3, ->(*_) { raise Errno::ENOENT }) do
      refute GT::CLI.gh_installed?
    end
  end

  def test_unknown_command_exits_1
    ex = nil
    capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["bogus"]) } }
    assert_equal 1, ex.status
  end

  def test_create_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["create"]) } }
  end

  def test_log_dispatches
    capture_io { GT::CLI.run(["log"]) }
  end

  def test_ls_dispatches
    capture_io { GT::CLI.run(["ls"]) }
  end

  def test_git_error_exits_2
    GT::State.stub(:new, -> { raise GT::GitError, "broken" }) do
      ex = nil
      capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["log"]) } }
      assert_equal 2, ex.status
    end
  end

  def test_restack_blocked_when_state_active
    GT::State.new.save(branches: ["feature"], index: 0)
    ex = nil
    capture_io { ex = assert_raises(SystemExit) { GT::CLI.run(["log"]) } }
    assert_equal 1, ex.status
  end

  def test_restack_allowed_when_state_active
    GT::State.new.save(branches: %w[main feature], index: 0)
    GT::Commands::Restack.stub(:run, nil) do
      capture_io { GT::CLI.run(["restack"]) }
    end
  end

  def test_modify_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["modify"]) } }
  end

  def test_m_alias_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["m"]) } }
  end

  def test_sync_dispatches
    GT::Git.stub(:pull, nil) do
      GT::Commands::Restack.stub(:run, nil) do
        capture_io { GT::CLI.run(["sync"]) }
      end
    end
  end

  def test_up_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["up"]) } }
  end

  def test_down_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["down"]) } }
  end

  def test_top_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["top"]) } }
  end

  def test_checkout_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["checkout"]) } }
  end

  def test_co_alias_dispatches
    capture_io { assert_raises(SystemExit) { GT::CLI.run(["co"]) } }
  end

  def test_help_flag
    out, = capture_io { GT::CLI.run(["--help"]) }
    assert_match "Usage", out
  end

  def test_no_args_shows_usage
    out, = capture_io { GT::CLI.run([]) }
    assert_match "Usage", out
  end

  def test_version_flag
    out, = capture_io { GT::CLI.run(["--version"]) }
    assert_match GT::VERSION, out
  end
end
