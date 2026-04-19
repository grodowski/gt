# frozen_string_literal: true

require "json"

module GT
  module GitHub
    module_function

    def pr_merged?(branch)
      out, _, status = Open3.capture3("gh pr view #{branch} --json state --jq .state")
      return false unless status.success?

      out.strip == "MERGED"
    rescue Errno::ENOENT
      false
    end

    def pr_retarget(branch, base)
      out, err, status = Open3.capture3("gh pr edit #{branch} --base #{base}")
      unless status.success?
        GT::UI.warn("Failed to retarget PR '#{branch}' to '#{base}': #{(err.strip.empty? ? out : err).strip}")
      end
      status.success?
    rescue Errno::ENOENT
      false
    end

    def merged_into(branch)
      out, _, status = Open3.capture3("gh pr view #{branch} --json mergeCommit --jq .mergeCommit.oid")
      return nil unless status.success?

      sha = out.strip
      sha.empty? ? nil : sha
    end

    STACK_MARKER = "<!-- gt-stack -->"

    def repo_url
      out, _, status = Open3.capture3("gh repo view --json url --jq .url")
      return nil unless status.success?

      url = out.strip
      url.empty? ? nil : url
    rescue Errno::ENOENT
      nil
    end

    # Returns { "branch-name" => pr_number } for all open PRs whose branch is in +branches+.
    # Uses a single gh pr list call. Returns {} on any failure.
    def pr_numbers(branches)
      out, _, status = Open3.capture3(
        "gh pr list --json number,headRefName " \
        "--jq 'map({(.headRefName): .number}) | add'"
      )
      return {} unless status.success?

      data = JSON.parse(out.strip)
      return {} unless data.is_a?(Hash)

      data.select { |branch, _| branches.include?(branch) }
    rescue JSON::ParserError, Errno::ENOENT
      {}
    end

    def stack_comment_body(branches, current_branch, pr_nums, base_url = nil)
      lines = ["[gt](https://github.com/grodowski/gt) stack", ""]
      branches.each do |branch|
        num = pr_nums[branch]
        if branch == current_branch
          pr_url = base_url && num ? "#{base_url}/pull/#{num}" : (num ? "##{num}" : nil)
          lines << (pr_url ? "- 👉 #{pr_url}" : "- 👉 **#{branch}**")
        else
          pr_url = base_url && num ? "#{base_url}/pull/#{num}" : (num ? "##{num}" : nil)
          lines << (pr_url ? "- #{pr_url}" : "- #{branch}")
        end
      end
      lines << ""
      lines << STACK_MARKER
      lines.join("\n")
    end

    def find_stack_comment_id(pr_number)
      out, _, status = Open3.capture3(
        "gh api repos/{owner}/{repo}/issues/#{pr_number}/comments " \
        "--jq '[.[] | select(.body | contains(\"#{STACK_MARKER}\")) | .id] | first'"
      )
      return nil unless status.success?

      id = out.strip
      (id.empty? || id == "null") ? nil : id.to_i
    end

    def upsert_stack_comment(pr_number, body)
      json = JSON.generate({ body: body })
      existing_id = find_stack_comment_id(pr_number)
      if existing_id
        Open3.capture3(
          "gh api repos/{owner}/{repo}/issues/comments/#{existing_id} -X PATCH --input -",
          stdin_data: json
        )
      else
        Open3.capture3(
          "gh api repos/{owner}/{repo}/issues/#{pr_number}/comments --input -",
          stdin_data: json
        )
      end
    end

    def update_stack_comments(branches)
      nums = pr_numbers(branches)
      url = repo_url
      branches[1..].each do |branch|
        next unless nums[branch]

        body = stack_comment_body(branches, branch, nums, url)
        upsert_stack_comment(nums[branch], body)
      end
    rescue StandardError
      # Best-effort — silently skip if GitHub API is unavailable
    end
  end
end
