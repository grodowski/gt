# frozen_string_literal: true

require "test_helper"

class GitTest < Minitest::Test
  include GitSandbox

  def test_current_branch
    assert_equal "main", GT::Git.current_branch
  end

  def test_checkout_existing_branch
    system("git branch other", out: File::NULL, err: File::NULL)
    GT::Git.checkout("other")
    assert_equal "other", GT::Git.current_branch
  end

  def test_checkout_new_branch
    GT::Git.checkout("feature", new_branch: true)
    assert_equal "feature", GT::Git.current_branch
  end

  def test_add_all_and_commit
    write_file("hello.txt", "hello")
    GT::Git.add_all
    GT::Git.commit("add hello")
    log = `git log --oneline`.strip
    assert_match "add hello", log
  end

  def test_rev_parse
    sha = GT::Git.rev_parse("HEAD")
    assert_match(/\A[0-9a-f]{40}\z/, sha)
  end

  def test_merge_base
    # Create a branch and a commit on it
    GT::Git.checkout("feature", new_branch: true)
    write_file("f.txt")
    GT::Git.add_all
    GT::Git.commit("on feature")

    base = GT::Git.merge_base("main", "feature")
    assert_match(/\A[0-9a-f]{40}\z/, base)
  end

  def test_config_set_and_get
    GT::Git.config_set("branch.main.gt-parent", "trunk")
    assert_equal "trunk", GT::Git.config_get("branch.main.gt-parent")
  end

  def test_config_get_missing_key
    assert_nil GT::Git.config_get("branch.main.gt-does-not-exist")
  end

  def test_config_unset
    GT::Git.config_set("branch.main.gt-parent", "trunk")
    GT::Git.config_unset("branch.main.gt-parent")
    assert_nil GT::Git.config_get("branch.main.gt-parent")
  end

  def test_gt_parent_helpers
    GT::Git.set_gt_parent("feature", "main")
    assert_equal "main", GT::Git.gt_parent("feature")
  end

  def test_gt_fork_point_helpers
    sha = GT::Git.rev_parse("HEAD")
    GT::Git.set_gt_fork_point("feature", sha)
    assert_equal sha, GT::Git.gt_fork_point("feature")
  end

  def test_unset_gt_meta
    GT::Git.set_gt_parent("feature", "main")
    GT::Git.set_gt_fork_point("feature", GT::Git.rev_parse("HEAD"))
    GT::Git.unset_gt_meta("feature")
    assert_nil GT::Git.gt_parent("feature")
    assert_nil GT::Git.gt_fork_point("feature")
  end

  def test_push
    GT::Git.checkout("feature", new_branch: true)
    write_file("f.txt")
    GT::Git.add_all
    GT::Git.commit("feature commit")
    GT::Git.push("feature")
    branches = `git -C #{@remote_dir} branch`.strip
    assert_match "feature", branches
  end

  def test_run_raises_git_error_on_failure
    assert_raises(GT::GitError) { GT::Git.run("git checkout nonexistent-branch-xyz") }
  end

  def test_rebase_onto
    # main: A
    # feature: A -> B        (fork_point for child = SHA of B)
    # child:   A -> B -> C
    # After rebase --onto main B child: main -> C (only C replayed)
    GT::Git.checkout("feature", new_branch: true)
    write_file("b.txt")
    GT::Git.add_all
    GT::Git.commit("B")

    fork_point = GT::Git.rev_parse("HEAD") # SHA of B

    GT::Git.checkout("child", new_branch: true)
    write_file("c.txt")
    GT::Git.add_all
    GT::Git.commit("C")

    GT::Git.checkout("main")
    GT::Git.rebase_onto("main", fork_point, "child")

    GT::Git.checkout("child")
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["C", "init"], log
  end
end
