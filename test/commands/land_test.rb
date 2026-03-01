# frozen_string_literal: true

require "test_helper"

class LandTest < Minitest::Test
  include GitSandbox

  def create_branch(name, message)
    write_file("#{name}.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::Commands::Create.run([name, "-m", message])
      end
    end
  end

  def setup
    super
    create_branch("feature", "F")
    create_branch("child", "C")
    GT::Git.checkout("main")
  end

  def with_merged_pr(branch)
    GT::GitHub.stub(:pr_merged?, ->(b) { b == branch }, ) do
      GT::GitHub.stub(:pr_retarget, true) do
        yield
      end
    end
  end

  def test_raises_when_nothing_to_land
    # Only main, no stacked branches
    GT::Git.run("git config --remove-section branch.feature") rescue nil
    GT::Git.run("git config --remove-section branch.child") rescue nil
    assert_raises(GT::UserError) { capture_io { GT::Commands::Land.run([]) } }
  end

  def test_raises_when_pr_not_merged
    GT::GitHub.stub(:pr_merged?, false) do
      assert_raises(GT::UserError) { capture_io { GT::Commands::Land.run([]) } }
    end
  end

  def test_land_deletes_bottom_branch
    with_merged_pr("feature") do
      capture_io { GT::Commands::Land.run([]) }
    end
    branches = GT::Git.all_branches
    refute_includes branches, "feature"
  end

  def test_land_retargets_child_to_root
    retargeted = []
    GT::GitHub.stub(:pr_merged?, ->(b) { b == "feature" }) do
      GT::GitHub.stub(:pr_retarget, ->(b, base) { retargeted << [b, base] }) do
        capture_io { GT::Commands::Land.run([]) }
      end
    end
    assert_includes retargeted, ["child", "main"]
  end

  def test_land_rebases_child_onto_root
    with_merged_pr("feature") do
      capture_io { GT::Commands::Land.run([]) }
    end
    GT::Git.checkout("child")
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["C", "init"], log
  end

  def test_land_updates_child_parent_to_root
    with_merged_pr("feature") do
      capture_io { GT::Commands::Land.run([]) }
    end
    assert_equal "main", GT::Git.gt_parent("child")
  end

  def test_land_clears_gt_meta_for_landed_branch
    with_merged_pr("feature") do
      capture_io { GT::Commands::Land.run([]) }
    end
    assert_nil GT::Git.gt_parent("feature")
    assert_nil GT::Git.gt_fork_point("feature")
  end

  def test_land_with_no_child
    # Only main -> feature, no child
    GT::Git.run("git config --remove-section branch.child") rescue nil
    GT::Git.run("git branch -D child") rescue nil

    with_merged_pr("feature") do
      out, = capture_io { GT::Commands::Land.run([]) }
      assert_match "Landed feature", out
    end
    refute_includes GT::Git.all_branches, "feature"
  end

  def test_land_with_grandchild_triggers_restack
    # main -> feature -> child -> grandchild
    GT::Git.checkout("child")
    write_file("grand.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::Commands::Create.run(["grandchild", "-m", "G"])
      end
    end
    GT::Git.checkout("main")

    with_merged_pr("feature") do
      out, = capture_io { GT::Commands::Land.run([]) }
      assert_match "Restacking", out
    end
  end
end
