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

  def test_patch_flag_calls_add_patch
    write_file("feature.txt", "work")
    patched = false
    # Stub add_patch to record the call and still stage (so commit succeeds)
    GT::Git.stub(:add_patch, -> { patched = true; system("git add -A", out: File::NULL, err: File::NULL) }) do
      capture_io do
        GT::Commands::Create.stub(:system, true) do
          GT::Commands::Create.run(["my-feature", "-m", "msg", "-p"])
        end
      end
    end
    assert patched
  end

  def test_patch_flag_skips_add_all
    write_file("feature.txt", "work")
    all_called = false
    GT::Git.stub(:add_patch, -> { system("git add -A", out: File::NULL, err: File::NULL) }) do
      GT::Git.stub(:add_all, -> { all_called = true }) do
        capture_io do
          GT::Commands::Create.stub(:system, true) do
            GT::Commands::Create.run(["my-feature", "-m", "msg", "-p"])
          end
        end
      end
    end
    refute all_called
  end
end
