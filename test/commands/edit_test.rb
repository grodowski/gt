# frozen_string_literal: true

require "test_helper"

class EditTest < Minitest::Test
  include GitSandbox

  def setup
    super
    write_file("feature.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::Commands::Create.run(["feature", "-m", "original message"])
      end
    end
  end

  def test_edit_changes_commit_message
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Edit.run(["-m", "updated message"]) }
    end
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["updated message", "init"], log
  end

  def test_edit_force_pushes
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Edit.run(["-m", "updated message"]) }
    end
    remote_log = `git -C #{@remote_dir} log feature --oneline 2>/dev/null`.strip
    assert_match "updated message", remote_log
  end

  def test_edit_raises_without_message_flag
    assert_raises(GT::UserError) { GT::Commands::Edit.run([]) }
  end

  def test_edit_raises_without_message_value
    assert_raises(GT::UserError) { GT::Commands::Edit.run(["-m"]) }
  end

  def test_edit_raises_on_main
    GT::Git.checkout("main")
    assert_raises(GT::UserError) { GT::Commands::Edit.run(["-m", "msg"]) }
  end
end
