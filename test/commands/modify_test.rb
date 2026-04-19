# frozen_string_literal: true

require "test_helper"

class ModifyTest < Minitest::Test
  include GitSandbox

  def setup
    super
    write_file("feature.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::UI.stub(:confirm, true) do
          GT::Commands::Create.run(["feature", "-m", "F"])
        end
      end
    end
  end

  # ── gt modify (amend all staged changes) ───────────────────────────────────

  def test_modify_amends_commit
    write_file("extra.txt", "more work")
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Modify.run([]) }
    end
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["F", "init"], log
    assert File.exist?("extra.txt")
  end

  def test_modify_force_pushes
    write_file("extra.txt", "more work")
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Modify.run([]) }
    end
    remote_log = `git -C #{@remote_dir} log feature --oneline 2>/dev/null`.strip
    assert_match "F", remote_log
  end

  def test_modify_raises_on_main
    GT::Git.checkout("main")
    assert_raises(GT::UserError) { GT::Commands::Modify.run([]) }
  end

  # ── gt modify -m (change commit message) ───────────────────────────────────

  def test_modify_with_message_changes_commit_message
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Modify.run(["-m", "updated message"]) }
    end
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["updated message", "init"], log
  end

  def test_modify_with_message_force_pushes
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Modify.run(["-m", "updated message"]) }
    end
    remote_log = `git -C #{@remote_dir} log feature --oneline 2>/dev/null`.strip
    assert_match "updated message", remote_log
  end

  def test_modify_with_message_raises_without_value
    assert_raises(GT::UserError) { GT::Commands::Modify.run(["-m"]) }
  end

  def test_modify_with_message_raises_on_main
    GT::Git.checkout("main")
    assert_raises(GT::UserError) { GT::Commands::Modify.run(["-m", "msg"]) }
  end

  # ── gt modify -p (interactive patch staging) ───────────────────────────────

  def test_modify_patch_calls_add_patch
    write_file("extra.txt", "more work")
    patched = false
    GT::Git.stub(:add_patch, -> { patched = true; system("git add -A", out: File::NULL, err: File::NULL) }) do
      GT::GitHub.stub(:pr_merged?, false) do
        capture_io { GT::Commands::Modify.run(["-p"]) }
      end
    end
    assert patched
  end

  def test_modify_patch_does_not_call_add_all
    write_file("extra.txt", "more work")
    all_called = false
    GT::Git.stub(:add_patch, -> { system("git add -A", out: File::NULL, err: File::NULL) }) do
      GT::Git.stub(:add_all, -> { all_called = true }) do
        GT::GitHub.stub(:pr_merged?, false) do
          capture_io { GT::Commands::Modify.run(["-p"]) }
        end
      end
    end
    refute all_called
  end
end
