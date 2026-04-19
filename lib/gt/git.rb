# frozen_string_literal: true

require "open3"
require "shellwords"

module GT
  module Git
    module_function

    def current_branch
      run("git rev-parse --abbrev-ref HEAD").strip
    end

    def checkout(branch, new_branch: false)
      if new_branch
        run("git checkout -b #{branch}")
      else
        run("git checkout #{branch}")
      end
    end

    def add_all
      run("git add -A")
    end

    def add_tracked
      run("git add -u")
    end

    def add_file(path)
      run("git add -- #{Shellwords.escape(path)}")
    end

    def untracked_files
      out, _, status = Open3.capture3("git ls-files --others --exclude-standard")
      return [] unless status.success?

      out.strip.split("\n").reject(&:empty?)
    end

    def add_patch
      system("git add --patch")
    end

    def commit(message)
      run("git commit -m #{Shellwords.escape(message)}")
    end

    def push(branch, force: false)
      flag = force ? "--force-with-lease" : ""
      run("git push #{flag} origin #{branch}".strip)
    end

    def rev_parse(ref)
      run("git rev-parse #{ref}").strip
    end

    def merge_base(a, b)
      run("git merge-base #{a} #{b}").strip
    end

    def ancestor?(branch, parent)
      _, _, status = Open3.capture3("git merge-base --is-ancestor #{branch} #{parent}")
      status.success?
    end

    def rebase_onto(new_base, fork_point, branch)
      run("git rebase --onto #{new_base} #{fork_point} #{branch}")
    end

    def rebase_continue
      run("GIT_EDITOR=true git rebase --continue")
    end

    def rebase_abort
      run("git rebase --abort")
    end

    def rebase_in_progress?
      File.exist?(File.join(git_dir, "rebase-merge")) ||
        File.exist?(File.join(git_dir, "rebase-apply"))
    end

    def config_set(key, value)
      run("git config #{key} #{Shellwords.escape(value)}")
    end

    def config_get(key)
      out, _, status = Open3.capture3("git config #{key}")
      status.success? ? out.strip : nil
    end

    def config_unset(key)
      _out, _err, _status = Open3.capture3("git config --unset #{key}")
    end

    def gt_parent(branch)
      config_get("branch.#{branch}.gt-parent")
    end

    def gt_fork_point(branch)
      config_get("branch.#{branch}.gt-fork-point")
    end

    def set_gt_parent(branch, parent)
      run("git config branch.#{branch}.gt-parent #{Shellwords.escape(parent)}")
    end

    def set_gt_fork_point(branch, sha)
      run("git config branch.#{branch}.gt-fork-point #{Shellwords.escape(sha)}")
    end

    def unset_gt_meta(branch)
      config_unset("branch.#{branch}.gt-parent")
      config_unset("branch.#{branch}.gt-fork-point")
    end

    def main_branch
      config_get("gt.main-branch") || "main"
    end

    def pull
      run("git pull")
    end

    def amend(message: nil)
      if message
        run("git commit --amend -m #{Shellwords.escape(message)}")
      else
        run("git commit --amend --no-edit")
      end
    end

    def all_branches
      out, _, _ = Open3.capture3("git", "branch")
      out.strip.split("\n").map { |b| b.delete_prefix("* ").strip }
    end

    def git_dir
      run("git rev-parse --git-dir").strip
    end

    def run(cmd)
      out, err, status = Open3.capture3(cmd)
      raise GT::GitError, "#{cmd}\n#{err.strip}" unless status.success?

      out
    end
  end
end
