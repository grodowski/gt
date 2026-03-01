# frozen_string_literal: true

require "test_helper"

class GitHubTest < Minitest::Test
  def test_pr_merged_returns_true_when_merged
    Open3.stub(:capture3, [+"MERGED\n", +"", double_status(true)]) do
      assert GT::GitHub.pr_merged?("feature")
    end
  end

  def test_pr_merged_returns_false_when_open
    Open3.stub(:capture3, [+"OPEN\n", +"", double_status(true)]) do
      refute GT::GitHub.pr_merged?("feature")
    end
  end

  def test_pr_merged_returns_false_when_gh_fails
    Open3.stub(:capture3, [+"", +"error", double_status(false)]) do
      refute GT::GitHub.pr_merged?("feature")
    end
  end

  def test_pr_retarget_calls_system
    called = []
    GT::GitHub.stub(:system, ->(cmd) { called << cmd }) do
      GT::GitHub.pr_retarget("child", "main")
    end
    assert_equal ["gh pr edit child --base main"], called
  end

  def test_merged_into_returns_sha
    Open3.stub(:capture3, [+"abc123\n", +"", double_status(true)]) do
      assert_equal "abc123", GT::GitHub.merged_into("feature")
    end
  end

  def test_merged_into_returns_nil_when_empty
    Open3.stub(:capture3, [+"", +"", double_status(true)]) do
      assert_nil GT::GitHub.merged_into("feature")
    end
  end

  def test_merged_into_returns_nil_when_gh_fails
    Open3.stub(:capture3, [+"", +"error", double_status(false)]) do
      assert_nil GT::GitHub.merged_into("feature")
    end
  end

  private

  def double_status(success)
    status = Object.new
    status.define_singleton_method(:success?) { success }
    status
  end
end
