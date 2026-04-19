# frozen_string_literal: true

module GT
  module Commands
    class Create
      def self.run(argv)
        name = argv.shift
        raise GT::UserError, "Usage: gt create <name> [-m <message>] [-p]" if name.nil?

        msg_idx = argv.index("-m")
        message = msg_idx ? argv[msg_idx + 1] : name
        raise GT::UserError, "Usage: gt create <name> [-m <message>] [-p]" if msg_idx && message.nil?

        patch = argv.include?("-p")
        parent = GT::Git.current_branch
        fork_point = GT::Git.rev_parse("HEAD")

        # All interactive staging must happen before the spinner (SpinGroup masks stdin)
        if patch
          GT::Git.add_patch
        else
          GT::Git.add_tracked
          GT::Git.untracked_files.each do |file|
            GT::Git.add_file(file) if GT::UI.confirm("Include untracked file '#{file}'?")
          end
        end

        GT::UI.spinner("Creating branch #{name}") do
          GT::Git.checkout(name, new_branch: true)
          GT::Git.commit(message)
          GT::Git.set_gt_parent(name, parent)
          GT::Git.set_gt_fork_point(name, fork_point)
          GT::Git.push(name)
        end

        GT::UI.info("Opening PR for {{bold:#{name}}} → {{bold:#{parent}}}")
        system("gh pr create --base #{parent} --head #{name} --fill")

        GT::UI.spinner("Updating stack comments") do
          GT::GitHub.update_stack_comments(GT::Stack.build_all)
        end
      end
    end
  end
end
