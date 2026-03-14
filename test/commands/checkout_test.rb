# frozen_string_literal: true

require "test_helper"

class CheckoutTest < Minitest::Test
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

  def test_checkout_with_arg_switches_branch
    GT::Commands::Checkout.run(["feature"])
    assert_equal "feature", GT::Git.current_branch
  end

  def test_checkout_with_arg_to_root
    GT::Commands::Checkout.run(["main"])
    assert_equal "main", GT::Git.current_branch
  end

  def test_checkout_stays_when_current_selected
    GT::Commands::Checkout.run(["child"])
    assert_equal "child", GT::Git.current_branch
  end

  def test_checkout_interactive_selects_branch
    GT::UI.stub(:prompt_select, "feature") do
      GT::Commands::Checkout.run([])
    end
    assert_equal "feature", GT::Git.current_branch
  end

  def test_checkout_raises_for_unknown_branch
    assert_raises(GT::UserError) { GT::Commands::Checkout.run(["nonexistent"]) }
  end

  def test_checkout_raises_when_no_stack
    GT::Git.checkout("main")
    GT::Git.run("git branch -D feature") rescue nil
    GT::Git.run("git branch -D child") rescue nil
    assert_raises(GT::UserError) { GT::Commands::Checkout.run([]) }
  end
end
