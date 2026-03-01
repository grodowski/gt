# frozen_string_literal: true

require "test_helper"

class RestackTest < Minitest::Test
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
    # main: init
    # feature: init -> F  (fork_point = SHA of init)
    # child:   init -> F -> C  (fork_point = SHA of F)
    create_branch("feature", "F")
    create_branch("child", "C")

    # Add a new commit to main (simulating merged work)
    GT::Git.checkout("main")
    write_file("main2.txt", "main update")
    GT::Git.add_all
    GT::Git.commit("main update")
  end

  def test_restack_happy_path
    capture_io { GT::Commands::Restack.run([]) }

    GT::Git.checkout("feature")
    feature_log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["F", "main update", "init"], feature_log

    GT::Git.checkout("child")
    child_log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["C", "F", "main update", "init"], child_log
  end

  def test_restack_updates_fork_points
    main_tip = GT::Git.rev_parse("main")
    capture_io { GT::Commands::Restack.run([]) }

    assert_equal main_tip, GT::Git.gt_fork_point("feature")
  end

  def test_restack_force_pushes
    capture_io { GT::Commands::Restack.run([]) }
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

  def test_complete_prints_message
    out, = capture_io { GT::Commands::Restack.run([]) }
    assert_match "Restack complete", out
  end
end
