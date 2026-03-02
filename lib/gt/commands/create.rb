# frozen_string_literal: true

module GT
  module Commands
    class Create
      def self.run(argv)
        name = argv.shift
        raise GT::UserError, "Usage: gt create <name> -m <message>" if name.nil?

        msg_idx = argv.index("-m")
        raise GT::UserError, "Usage: gt create <name> -m <message>" if msg_idx.nil?

        message = argv[msg_idx + 1]
        raise GT::UserError, "Usage: gt create <name> -m <message>" if message.nil?

        parent = GT::Git.current_branch
        fork_point = GT::Git.rev_parse("HEAD")

        GT::UI.spinner("Creating branch #{name}") do
          GT::Git.add_all
          GT::Git.checkout(name, new_branch: true)
          GT::Git.commit(message)
          GT::Git.set_gt_parent(name, parent)
          GT::Git.set_gt_fork_point(name, fork_point)
          GT::Git.push(name)
        end

        GT::UI.info("Opening PR for {{bold:#{name}}} → {{bold:#{parent}}}")
        system("gh pr create --base #{parent} --head #{name} --fill")
      end
    end
  end
end
