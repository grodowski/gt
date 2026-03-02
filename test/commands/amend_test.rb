# frozen_string_literal: true

require "test_helper"

class AmendTest < Minitest::Test
  include GitSandbox

  def setup
    super
    write_file("feature.txt")
    capture_io do
      GT::Commands::Create.stub(:system, true) do
        GT::Commands::Create.run(["feature", "-m", "F"])
      end
    end
  end

  def test_amend_updates_commit
    write_file("extra.txt", "more work")
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Amend.run([]) }
    end
    log = `git log --oneline`.strip.split("\n").map { _1.split(" ", 2).last }
    assert_equal ["F", "init"], log
    assert File.exist?("extra.txt")
  end

  def test_amend_force_pushes
    write_file("extra.txt", "more work")
    GT::GitHub.stub(:pr_merged?, false) do
      capture_io { GT::Commands::Amend.run([]) }
    end
    remote_log = `git -C #{@remote_dir} log feature --oneline 2>/dev/null`.strip
    assert_match "F", remote_log
  end

  def test_amend_raises_on_main
    GT::Git.checkout("main")
    assert_raises(GT::UserError) { GT::Commands::Amend.run([]) }
  end
end
