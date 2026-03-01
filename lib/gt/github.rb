# frozen_string_literal: true

require "json"

module GT
  module GitHub
    module_function

    def pr_merged?(branch)
      out, _, status = Open3.capture3("gh pr view #{branch} --json state --jq .state")
      return false unless status.success?

      out.strip == "MERGED"
    end

    def pr_retarget(branch, base)
      system("gh pr edit #{branch} --base #{base}")
    end

    def merged_into(branch)
      out, _, status = Open3.capture3("gh pr view #{branch} --json mergeCommit --jq .mergeCommit.oid")
      return nil unless status.success?

      sha = out.strip
      sha.empty? ? nil : sha
    end
  end
end
