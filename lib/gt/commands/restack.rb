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
        restack_from(branches, 1, state)
      end

      def self.handle_abort(state)
        GT::Git.rebase_abort if GT::Git.rebase_in_progress?
        state.clear
        puts "Restack aborted."
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
        start_index.upto(branches.length - 1) do |i|
          branch = branches[i]
          parent = GT::Git.gt_parent(branch)
          fork_point = GT::Git.gt_fork_point(branch)

          GT::Git.checkout(branch)

          begin
            GT::Git.rebase_onto(parent, fork_point, branch)
          rescue GT::GitError
            new_fork_point = GT::Git.rev_parse(parent)
            state.save(branches: branches, index: i, pending_fork_point: new_fork_point)
            puts "Conflict on #{branch}. Resolve and run `gt restack --continue`."
            return
          end

          GT::Git.set_gt_fork_point(branch, GT::Git.rev_parse(parent))
          GT::Git.push(branch, force: true)
        end

        state.clear
        puts "Restack complete."
      end

      private_class_method :handle_abort, :handle_continue, :restack_from
    end
  end
end
