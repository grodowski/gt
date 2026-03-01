# frozen_string_literal: true

require "test_helper"

class CreateTest < Minitest::Test
  include GitSandbox

  def create(name, message)
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::Commands::Create.run([name, "-m", message])
      end
    end
  end

  def test_creates_branch_and_commits
    write_file("feature.txt", "work")
    create("my-feature", "add feature")

    assert_equal "my-feature", GT::Git.current_branch
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["add feature", "init"], log
  end

  def test_stores_parent_metadata
    write_file("feature.txt", "work")
    create("my-feature", "add feature")

    assert_equal "main", GT::Git.gt_parent("my-feature")
  end

  def test_stores_fork_point_as_parent_tip
    parent_sha = GT::Git.rev_parse("HEAD")
    write_file("feature.txt", "work")
    create("my-feature", "add feature")

    assert_equal parent_sha, GT::Git.gt_fork_point("my-feature")
  end

  def test_pushes_branch
    write_file("feature.txt", "work")
    create("my-feature", "add feature")

    branches = `git -C #{@remote_dir} branch`.strip.split("\n").map(&:strip)
    assert_includes branches, "my-feature"
  end

  def test_raises_without_name
    assert_raises(GT::UserError) { GT::Commands::Create.run([]) }
  end

  def test_raises_without_message_flag
    assert_raises(GT::UserError) { GT::Commands::Create.run(["my-feature"]) }
  end

  def test_raises_without_message_value
    assert_raises(GT::UserError) { GT::Commands::Create.run(["my-feature", "-m"]) }
  end
end
