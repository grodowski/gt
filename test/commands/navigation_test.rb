# frozen_string_literal: true

require "test_helper"

class NavigationTest < Minitest::Test
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
    # Now on child; stack is main -> feature -> child
  end

  # ── gt up ──────────────────────────────────────────────────────────────────

  def test_up_moves_to_next_branch
    GT::Git.checkout("feature")
    GT::Commands::Up.run([])
    assert_equal "child", GT::Git.current_branch
  end

  def test_up_from_root_moves_to_feature
    GT::Git.checkout("main")
    GT::Commands::Up.run([])
    assert_equal "feature", GT::Git.current_branch
  end

  def test_up_at_top_raises
    assert_raises(GT::UserError) { GT::Commands::Up.run([]) }
  end

  def test_up_on_untracked_branch_raises
    GT::Git.checkout("main")
    GT::Git.checkout("orphan", new_branch: true)
    assert_raises(GT::UserError) { GT::Commands::Up.run([]) }
  end

  # ── gt down ────────────────────────────────────────────────────────────────

  def test_down_moves_to_previous_branch
    GT::Commands::Down.run([])
    assert_equal "feature", GT::Git.current_branch
  end

  def test_down_from_feature_moves_to_main
    GT::Git.checkout("feature")
    GT::Commands::Down.run([])
    assert_equal "main", GT::Git.current_branch
  end

  def test_down_at_bottom_raises
    GT::Git.checkout("main")
    assert_raises(GT::UserError) { GT::Commands::Down.run([]) }
  end

  def test_down_on_untracked_branch_raises
    GT::Git.checkout("main")
    GT::Git.checkout("orphan", new_branch: true)
    assert_raises(GT::UserError) { GT::Commands::Down.run([]) }
  end

  # ── gt top ─────────────────────────────────────────────────────────────────

  def test_top_from_middle_jumps_to_top
    GT::Git.checkout("feature")
    capture_io { GT::Commands::Top.run([]) }
    assert_equal "child", GT::Git.current_branch
  end

  def test_top_already_at_top_prints_message
    out, = capture_io { GT::Commands::Top.run([]) }
    assert_equal "child", GT::Git.current_branch
    assert_match "Already at the top", out
  end

  def test_top_on_untracked_branch_raises
    GT::Git.checkout("main")
    GT::Git.checkout("orphan", new_branch: true)
    assert_raises(GT::UserError) { GT::Commands::Top.run([]) }
  end

  # ── gt switch ──────────────────────────────────────────────────────────────

  def test_switch_checks_out_selected_branch
    GT::UI.stub(:prompt_select, "feature") do
      GT::Commands::Switch.run([])
    end
    assert_equal "feature", GT::Git.current_branch
  end

  def test_switch_stays_when_current_selected
    GT::UI.stub(:prompt_select, "child") do
      GT::Commands::Switch.run([])
    end
    assert_equal "child", GT::Git.current_branch
  end

  def test_switch_raises_when_no_stack
    GT::Git.checkout("main")
    GT::Git.run("git branch -D feature") rescue nil
    GT::Git.run("git branch -D child") rescue nil
    assert_raises(GT::UserError) { GT::Commands::Switch.run([]) }
  end
end
