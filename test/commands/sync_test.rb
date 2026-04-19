# frozen_string_literal: true

require "test_helper"

class SyncTest < Minitest::Test
  include GitSandbox

  def setup
    super
    write_file("feature.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::UI.stub(:confirm, true) do
          GT::Commands::Create.run(["feature", "-m", "F"])
        end
      end
    end

    # Simulate a new commit on origin/main
    GT::Git.checkout("main")
    write_file("upstream.txt", "upstream work")
    GT::Git.add_all
    GT::Git.commit("upstream")
    GT::Git.push("main")

    # Reset local main behind origin
    GT::Git.run("git reset --hard HEAD~1")
    GT::Git.checkout("feature")
  end

  def test_sync_pulls_main
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Sync.run([]) }
    end
    GT::Git.checkout("main")
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_includes log, "upstream"
  end

  def test_sync_returns_to_original_branch
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Sync.run([]) }
    end
    assert_equal "feature", GT::Git.current_branch
  end

  def test_sync_uses_configured_main_branch
    GT::Git.config_set("gt.main-branch", "main")
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Sync.run([]) }
    end
    assert_equal "feature", GT::Git.current_branch
  end

  def test_sync_already_up_to_date_prints_message
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Sync.run([]) }  # pull once to get up to date
      out, = capture_io { GT::Commands::Sync.run([]) }  # second sync is a no-op
      assert_match "Already up to date", out
    end
  end

  def test_sync_raises_when_main_branch_not_found
    GT::Git.stub(:main_branch, "nonexistent") do
      assert_raises(GT::UserError) { GT::Commands::Sync.run([]) }
    end
  end
end
