# frozen_string_literal: true

module GT
  module Commands
    class Restack
      def self.run(argv)
        state = GT::State.new

        if argv.include?("--abort")
          return handle_abort(state)
        end

        if argv.include?("--continue")
          return handle_continue(state)
        end

        branches = GT::Stack.build_all
        raise GT::UserError, "No stack found. Use `gt create` to start one." if branches.length < 2

        maybe_delete_merged(branches)
        branches = GT::Stack.build_all
        restack_from(branches, 1, state)
      end

      def self.maybe_delete_merged(branches)
        return if branches.length < 2

        bottom = branches[1]
        return unless GT::GitHub.pr_merged?(bottom) || GT::Git.ancestor?(bottom, branches[0])

        return unless GT::UI.confirm("PR '#{bottom}' was merged. Delete branch and restack?")

        child = branches[2]
        if child
          fork_point = GT::Git.gt_fork_point(child)
          GT::GitHub.pr_retarget(child, branches[0])
          GT::Git.checkout(child)
          GT::Git.rebase_onto(branches[0], fork_point, child)
          GT::Git.set_gt_parent(child, branches[0])
          GT::Git.set_gt_fork_point(child, GT::Git.rev_parse(branches[0]))
          GT::Git.push(child, force: true)
        end

        GT::Git.checkout(branches[0])
        GT::Git.run("git branch -D #{bottom}")
        GT::Git.unset_gt_meta(bottom)
        GT::UI.success("Deleted #{bottom}.")
      end

      def self.handle_abort(state)
        GT::Git.rebase_abort if GT::Git.rebase_in_progress?
        state.clear
        GT::UI.info("Restack aborted.")
      end

      def self.handle_continue(state)
        raise GT::UserError, "No restack in progress." unless state.active?

        data = state.load
        branches = data[:branches].map(&:to_s)
        index = data[:index]
        new_fork_point = data[:pending_fork_point].to_s

        GT::Git.rebase_continue

        branch = branches[index]
        GT::Git.set_gt_fork_point(branch, new_fork_point)
        GT::Git.push(branch, force: true)

        restack_from(branches, index + 1, state)
      end

      def self.restack_from(branches, start_index, state)
        any_pushed = false
        start_index.upto(branches.length - 1) do |i|
          branch = branches[i]
          parent = GT::Git.gt_parent(branch)
          fork_point = GT::Git.gt_fork_point(branch)

          GT::Git.checkout(branch)
          sha_before = GT::Git.rev_parse(branch)

          begin
            GT::UI.spinner("Rebasing #{branch} onto #{parent}") do
              GT::Git.rebase_onto(parent, fork_point, branch)
            end
          rescue GT::GitError => e
            raise GT::UserError, "Please commit or stash your changes before restacking." if e.message.include?("unstaged changes")

            new_fork_point = GT::Git.rev_parse(parent)
            state.save(branches: branches, index: i, pending_fork_point: new_fork_point)
            GT::UI.warn("Conflict on #{branch}. Resolve and run `gt restack --continue`.")
            return
          end

          GT::Git.set_gt_fork_point(branch, GT::Git.rev_parse(parent))
          if GT::Git.rev_parse(branch) != sha_before
            any_pushed = true
            GT::UI.spinner("Pushing #{branch}") { GT::Git.push(branch, force: true) }
          end
        end

        state.clear
        if any_pushed
          GT::UI.spinner("Updating stack comments") do
            GT::GitHub.update_stack_comments(branches)
          end
          GT::UI.success("Restack complete.")
        else
          GT::UI.info("Already up to date.")
        end
      end

      private_class_method :handle_abort, :handle_continue, :restack_from, :maybe_delete_merged
    end
  end
end
