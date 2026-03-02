# frozen_string_literal: true

require "test_helper"

class RestackConflictTest < Minitest::Test
  include GitSandbox

  def setup
    super

    # main: init -> shared.txt="main"
    # feature (from init): shared.txt="feature" — conflicts with main's change
    write_file("shared.txt", "original")
    GT::Git.add_all
    GT::Git.commit("add shared")

    fork_point = GT::Git.rev_parse("HEAD")

    # feature branch: modifies shared.txt
    GT::Git.checkout("feature", new_branch: true)
    write_file("shared.txt", "feature version")
    GT::Git.add_all
    GT::Git.commit("feature change")
    GT::Git.set_gt_parent("feature", "main")
    GT::Git.set_gt_fork_point("feature", fork_point)
    GT::Git.push("feature")

    # back to main: conflicting change to shared.txt
    GT::Git.checkout("main")
    write_file("shared.txt", "main version")
    GT::Git.add_all
    GT::Git.commit("main change")
  end

  def test_conflict_saves_state
    capture_io { GT::Commands::Restack.run([]) }

    state = GT::State.new
    assert state.active?
    data = state.load
    assert_equal ["main", "feature"], data[:branches]
    assert_equal 1, data[:index]
  end

  def test_conflict_prints_message
    out, = capture_io { GT::Commands::Restack.run([]) }
    assert_match "Conflict on feature", out
  end

  def test_abort_clears_state_and_rebase
    capture_io { GT::Commands::Restack.run([]) }
    assert GT::Git.rebase_in_progress?

    capture_io { GT::Commands::Restack.run(["--abort"]) }

    refute GT::State.new.active?
    refute GT::Git.rebase_in_progress?
  end

  def test_continue_after_resolving_conflict
    capture_io { GT::Commands::Restack.run([]) }
    assert GT::Git.rebase_in_progress?

    # Resolve conflict and stage
    write_file("shared.txt", "resolved")
    GT::Git.add_all

    capture_io { GT::Commands::Restack.run(["--continue"]) }

    refute GT::State.new.active?
    refute GT::Git.rebase_in_progress?

    GT::Git.checkout("feature")
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["feature change", "main change", "add shared", "init"], log
  end

  def test_abort_prints_message
    capture_io { GT::Commands::Restack.run([]) }
    out, = capture_io { GT::Commands::Restack.run(["--abort"]) }
    assert_match "Restack aborted", out
  end

  def test_unstaged_changes_raises_user_error
    GT::Git.stub(:rebase_onto, -> (*) { raise GT::GitError, "error: cannot rebase: You have unstaged changes." }) do
      assert_raises(GT::UserError) { GT::Commands::Restack.run([]) }
    end
  end
end
