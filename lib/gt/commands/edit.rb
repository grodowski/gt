# frozen_string_literal: true

module GT
  module Commands
    class Edit
      def self.run(argv)
        msg_idx = argv.index("-m")
        raise GT::UserError, "Usage: gt edit -m <message>" if msg_idx.nil?

        message = argv[msg_idx + 1]
        raise GT::UserError, "Usage: gt edit -m <message>" if message.nil?

        branch = GT::Git.current_branch
        raise GT::UserError, "Cannot edit the main branch." if branch == GT::Git.main_branch

        GT::UI.spinner("Updating commit message") do
          GT::Git.amend(message: message)
          GT::Git.push(branch, force: true)
        end
        GT::Commands::Restack.run([])
      end
    end
  end
end
