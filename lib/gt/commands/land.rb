# frozen_string_literal: true

module GT
  module Commands
    class Land
      def self.run(_argv)
        branches = GT::Stack.build_all
        raise GT::UserError, "No stacked branches to land." if branches.length < 2

        root = branches[0]
        bottom = branches[1]
        child = branches[2] # may be nil

        raise GT::UserError, "PR for '#{bottom}' has not been merged yet." unless GT::GitHub.pr_merged?(bottom)

        puts "Landing #{bottom}..."

        if child
          fork_point = GT::Git.gt_fork_point(child)
          GT::GitHub.pr_retarget(child, root)
          GT::Git.checkout(child)
          GT::Git.rebase_onto(root, fork_point, child)
          new_fork_point = GT::Git.rev_parse(root)
          GT::Git.set_gt_parent(child, root)
          GT::Git.set_gt_fork_point(child, new_fork_point)
          GT::Git.push(child, force: true)
        end

        GT::Git.checkout(root)
        GT::Git.run("git branch -D #{bottom}")
        GT::Git.unset_gt_meta(bottom)

        if child && branches.length > 2
          remaining = [root] + branches[2..]
          puts "Restacking remaining branches..."
          GT::Commands::Restack.run([])
        end

        puts "Landed #{bottom}."
      end
    end
  end
end
