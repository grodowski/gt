# frozen_string_literal: true

require "test_helper"

class LogTest < Minitest::Test
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

  def test_single_branch_no_parent
    out = StringIO.new
    GT::Stack.print(output: out)
    assert_equal "main *\n", out.string
  end

  def test_two_level_stack
    create_branch("feature", "add feature")
    out = StringIO.new
    GT::Stack.print(output: out)
    assert_equal "main\n  └─ feature *\n", out.string
  end

  def test_three_level_stack
    create_branch("feature", "add feature")
    create_branch("child", "add child")
    out = StringIO.new
    GT::Stack.print(output: out)
    assert_equal "main\n  └─ feature\n    └─ child *\n", out.string
  end

  def test_build_returns_ordered_branches
    create_branch("feature", "add feature")
    create_branch("child", "add child")
    assert_equal %w[main feature child], GT::Stack.build
  end

  def test_marks_current_branch
    create_branch("feature", "add feature")
    GT::Git.checkout("main")
    out = StringIO.new
    GT::Stack.print(output: out)
    assert_match "main *", out.string
    refute_match "feature *", out.string
  end
end
