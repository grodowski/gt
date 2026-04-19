# frozen_string_literal: true

require "test_helper"

class RestackTest < Minitest::Test
  include GitSandbox

  def create_branch(name, message)
    write_file("#{name}.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::UI.stub(:confirm, true) do
          GT::Commands::Create.run([name, "-m", message])
        end
      end
    end
  end

  def no_merged_prs
    GT::GitHub.stub(:pr_merged?, false) { yield }
  end

  def setup
    super
    create_branch("feature", "F")
    create_branch("child", "C")

    GT::Git.checkout("main")
    write_file("main2.txt", "main update")
    GT::Git.add_all
    GT::Git.commit("main update")
  end

  def test_restack_happy_path
    no_merged_prs do
      capture_io { GT::Commands::Restack.run([]) }
    end

    GT::Git.checkout("feature")
    feature_log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["F", "main update", "init"], feature_log

    GT::Git.checkout("child")
    child_log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["C", "F", "main update", "init"], child_log
  end

  def test_restack_updates_fork_points
    main_tip = GT::Git.rev_parse("main")
    no_merged_prs { capture_io { GT::Commands::Restack.run([]) } }
    assert_equal main_tip, GT::Git.gt_fork_point("feature")
  end

  def test_restack_force_pushes
    no_merged_prs { capture_io { GT::Commands::Restack.run([]) } }
    branches = `git -C #{@remote_dir} branch`.strip.split("\n").map(&:strip)
    assert_includes branches, "feature"
    assert_includes branches, "child"
  end

  def test_abort_clears_state
    state = GT::State.new
    state.save(branches: %w[main feature], index: 1, pending_fork_point: "abc")
    GT::Git.stub(:rebase_in_progress?, false) do
      capture_io { GT::Commands::Restack.run(["--abort"]) }
    end
    refute state.active?
  end

  def test_continue_raises_without_active_state
    assert_raises(GT::UserError) { GT::Commands::Restack.run(["--continue"]) }
  end

  def test_restack_raises_when_no_stack
    GT::Stack.stub(:build_all, ["main"]) do
      assert_raises(GT::UserError) { GT::Commands::Restack.run([]) }
    end
  end

  def test_complete_prints_message
    no_merged_prs do
      out, = capture_io { GT::Commands::Restack.run([]) }
      assert_match "Restack complete", out
    end
  end

  def test_already_up_to_date_when_nothing_moved
    no_merged_prs do
      capture_io { GT::Commands::Restack.run([]) }  # first restack moves branches
      out, = capture_io { GT::Commands::Restack.run([]) }  # second is a no-op
      assert_match "Already up to date", out
    end
  end

  def test_prompts_when_bottom_pr_merged
    prompt_msg = nil
    GT::GitHub.stub(:pr_merged?, true) do
      GT::GitHub.stub(:pr_retarget, true) do
        GT::UI.stub(:confirm, ->(msg) { prompt_msg = msg; false }) do
          capture_io { GT::Commands::Restack.run([]) }
        end
      end
    end
    assert_match "feature", prompt_msg
    assert_match "merged", prompt_msg
  end


  def test_declines_deletion_skips_delete
    GT::GitHub.stub(:pr_merged?, true) do
      GT::GitHub.stub(:pr_retarget, true) do
        GT::UI.stub(:confirm, false) do
          capture_io { GT::Commands::Restack.run([]) }
        end
        assert_includes GT::Git.all_branches, "feature"
      end
    end
  end

  def test_confirms_deletion_deletes_branch
    GT::GitHub.stub(:pr_merged?, ->(b) { b == "feature" }) do
      GT::GitHub.stub(:pr_retarget, true) do
        GT::UI.stub(:confirm, true) do
          capture_io { GT::Commands::Restack.run([]) }
        end
        refute_includes GT::Git.all_branches, "feature"
      end
    end
  end

  def test_confirms_deletion_retargets_child
    retargeted = []
    GT::GitHub.stub(:pr_merged?, ->(b) { b == "feature" }) do
      GT::GitHub.stub(:pr_retarget, ->(b, base) { retargeted << [b, base] }) do
        GT::UI.stub(:confirm, true) do
          capture_io { GT::Commands::Restack.run([]) }
        end
      end
    end
    assert_includes retargeted, ["child", "main"]
  end

  def test_confirms_deletion_with_no_child
    GT::Git.run("git config --remove-section branch.child") rescue nil
    GT::Git.run("git branch -D child") rescue nil

    GT::GitHub.stub(:pr_merged?, ->(b) { b == "feature" }) do
      GT::GitHub.stub(:pr_retarget, true) do
        GT::UI.stub(:confirm, true) do
          out, = capture_io { GT::Commands::Restack.run([]) }
          assert_match "Deleted feature", out
        end
      end
    end
    refute_includes GT::Git.all_branches, "feature"
  end

  def test_confirms_deletion_rebases_child_onto_root
    GT::GitHub.stub(:pr_merged?, ->(b) { b == "feature" }) do
      GT::GitHub.stub(:pr_retarget, true) do
        GT::UI.stub(:confirm, true) do
          capture_io { GT::Commands::Restack.run([]) }
        end
      end
    end
    GT::Git.checkout("child")
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["C", "main update", "init"], log
  end
end
