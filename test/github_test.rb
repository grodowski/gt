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

  def test_pr_merged_returns_false_when_gh_not_installed
    Open3.stub(:capture3, ->(*_) { raise Errno::ENOENT }) do
      refute GT::GitHub.pr_merged?("feature")
    end
  end

  def test_pr_retarget_returns_true_on_success
    Open3.stub(:capture3, [+"", +"", double_status(true)]) do
      assert GT::GitHub.pr_retarget("child", "main")
    end
  end

  def test_pr_retarget_warns_on_failure
    Open3.stub(:capture3, [+"", +"some gh error", double_status(false)]) do
      out, = capture_io { GT::GitHub.pr_retarget("child", "main") }
      assert_match "Failed to retarget", out
    end
  end

  def test_pr_retarget_warns_using_stdout_when_stderr_empty
    Open3.stub(:capture3, [+"stdout error", +"", double_status(false)]) do
      out, = capture_io { GT::GitHub.pr_retarget("child", "main") }
      assert_match "stdout error", out
    end
  end

  def test_pr_retarget_returns_false_when_gh_missing
    Open3.stub(:capture3, ->(*) { raise Errno::ENOENT }) do
      refute GT::GitHub.pr_retarget("child", "main")
    end
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

  # ── pr_numbers ─────────────────────────────────────────────────────────────

  def test_pr_numbers_parses_json
    json = '{"feature":42,"child":43,"other":99}'
    Open3.stub(:capture3, ->(*_) { [+json, +"", double_status(true)] }) do
      result = GT::GitHub.pr_numbers(["feature", "child"])
      assert_equal({ "feature" => 42, "child" => 43 }, result)
    end
  end

  def test_pr_numbers_returns_empty_on_failure
    Open3.stub(:capture3, ->(*_) { [+"", +"err", double_status(false)] }) do
      assert_equal({}, GT::GitHub.pr_numbers(["feature"]))
    end
  end

  def test_pr_numbers_returns_empty_when_null
    Open3.stub(:capture3, ->(*_) { [+"null", +"", double_status(true)] }) do
      assert_equal({}, GT::GitHub.pr_numbers(["feature"]))
    end
  end

  def test_pr_numbers_returns_empty_on_invalid_json
    Open3.stub(:capture3, ->(*_) { [+"not-json", +"", double_status(true)] }) do
      assert_equal({}, GT::GitHub.pr_numbers(["feature"]))
    end
  end

  # ── stack_comment_body ──────────────────────────────────────────────────────

  def test_stack_comment_body_marks_current_branch
    branches = %w[main feature child]
    nums = { "feature" => 1, "child" => 2 }
    body = GT::GitHub.stack_comment_body(branches, "feature", nums)
    assert_match "[gt](https://github.com/grodowski/gt) stack", body
    assert_match "👉 #1", body
    assert_match "- #2", body
    assert_match "- main", body
    assert_match GT::GitHub::STACK_MARKER, body
  end

  def test_stack_comment_body_uses_full_url_when_base_url_given
    branches = %w[main feature child]
    nums = { "feature" => 1, "child" => 2 }
    body = GT::GitHub.stack_comment_body(branches, "feature", nums, "https://github.com/org/repo")
    assert_match "👉 https://github.com/org/repo/pull/1", body
    assert_match "- https://github.com/org/repo/pull/2", body
  end

  def test_stack_comment_body_current_branch_no_pr
    branches = %w[main feature]
    nums = {}
    body = GT::GitHub.stack_comment_body(branches, "feature", nums)
    assert_match "👉 **feature**", body
  end

  def test_stack_comment_body_branch_without_pr_shows_plain_name
    branches = %w[main feature child]
    nums = { "feature" => 1 }
    body = GT::GitHub.stack_comment_body(branches, "feature", nums)
    assert_match "- child", body
  end

  # ── repo_url ────────────────────────────────────────────────────────────────

  def test_repo_url_returns_url
    Open3.stub(:capture3, ->(*_) { [+"https://github.com/org/repo\n", +"", double_status(true)] }) do
      assert_equal "https://github.com/org/repo", GT::GitHub.repo_url
    end
  end

  def test_repo_url_returns_nil_on_failure
    Open3.stub(:capture3, ->(*_) { [+"", +"err", double_status(false)] }) do
      assert_nil GT::GitHub.repo_url
    end
  end

  def test_repo_url_returns_nil_when_empty
    Open3.stub(:capture3, ->(*_) { [+"", +"", double_status(true)] }) do
      assert_nil GT::GitHub.repo_url
    end
  end

  def test_repo_url_returns_nil_when_gh_not_installed
    Open3.stub(:capture3, ->(*_) { raise Errno::ENOENT }) do
      assert_nil GT::GitHub.repo_url
    end
  end

  # ── find_stack_comment_id ───────────────────────────────────────────────────

  def test_find_stack_comment_id_returns_id
    Open3.stub(:capture3, ->(*_) { [+"456\n", +"", double_status(true)] }) do
      assert_equal 456, GT::GitHub.find_stack_comment_id(42)
    end
  end

  def test_find_stack_comment_id_returns_nil_when_null
    Open3.stub(:capture3, ->(*_) { [+"null\n", +"", double_status(true)] }) do
      assert_nil GT::GitHub.find_stack_comment_id(42)
    end
  end

  def test_find_stack_comment_id_returns_nil_on_failure
    Open3.stub(:capture3, ->(*_) { [+"", +"err", double_status(false)] }) do
      assert_nil GT::GitHub.find_stack_comment_id(42)
    end
  end

  # ── upsert_stack_comment ────────────────────────────────────────────────────

  def test_upsert_creates_new_comment_when_none_exists
    calls = []
    GT::GitHub.stub(:find_stack_comment_id, nil) do
      Open3.stub(:capture3, ->(*args) { calls << args.first; [+"", +"", double_status(true)] }) do
        GT::GitHub.upsert_stack_comment(42, "body text")
      end
    end
    assert_match "issues/42/comments", calls.first
    refute_match "PATCH", calls.first
  end

  def test_upsert_patches_existing_comment
    calls = []
    GT::GitHub.stub(:find_stack_comment_id, 99) do
      Open3.stub(:capture3, ->(*args) { calls << args.first; [+"", +"", double_status(true)] }) do
        GT::GitHub.upsert_stack_comment(42, "body text")
      end
    end
    assert_match "issues/comments/99", calls.first
    assert_match "PATCH", calls.first
  end

  # ── update_stack_comments ───────────────────────────────────────────────────

  def test_update_stack_comments_upserts_for_each_pr
    upserted = []
    GT::GitHub.stub(:pr_numbers, { "feature" => 1, "child" => 2 }) do
      GT::GitHub.stub(:repo_url, "https://github.com/org/repo") do
        GT::GitHub.stub(:upsert_stack_comment, ->(num, _body) { upserted << num }) do
          GT::GitHub.update_stack_comments(%w[main feature child])
        end
      end
    end
    assert_equal [1, 2], upserted
  end

  def test_update_stack_comments_skips_branches_without_prs
    upserted = []
    GT::GitHub.stub(:pr_numbers, { "feature" => 1 }) do
      GT::GitHub.stub(:repo_url, nil) do
        GT::GitHub.stub(:upsert_stack_comment, ->(num, _body) { upserted << num }) do
          GT::GitHub.update_stack_comments(%w[main feature child])
        end
      end
    end
    assert_equal [1], upserted
  end

  def test_update_stack_comments_skips_root_branch
    upserted = []
    GT::GitHub.stub(:pr_numbers, { "main" => 99, "feature" => 1 }) do
      GT::GitHub.stub(:repo_url, nil) do
        GT::GitHub.stub(:upsert_stack_comment, ->(num, _body) { upserted << num }) do
          GT::GitHub.update_stack_comments(%w[main feature])
        end
      end
    end
    assert_equal [1], upserted  # main is branches[0], skipped by branches[1..]
  end

  def test_update_stack_comments_is_silent_on_error
    GT::GitHub.stub(:pr_numbers, ->(_) { raise "network error" }) do
      GT::GitHub.update_stack_comments(%w[main feature])  # must not raise
    end
  end

  private

  def double_status(success)
    status = Object.new
    status.define_singleton_method(:success?) { success }
    status
  end
end
