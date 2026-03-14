# frozen_string_literal: true

module GT
  module Commands
    class Modify
      def self.run(argv)
        msg_idx = argv.index("-m")
        message = msg_idx ? argv[msg_idx + 1] : nil
        raise GT::UserError, "Usage: gt modify [-m <message>] [-p]" if msg_idx && message.nil?

        patch = argv.include?("-p")
        branch = GT::Git.current_branch
        raise GT::UserError, "Cannot modify the main branch." if branch == GT::Git.main_branch

        # Interactive patch staging must happen before the spinner (SpinGroup masks stdin)
        if patch
          GT::Git.add_patch
        elsif !message
          # No message-only intent — stage everything (spinner will run below)
        end

        GT::UI.spinner("Modifying #{branch}") do
          GT::Git.add_all if !patch && !message
          GT::Git.amend(message: message)
          GT::Git.push(branch, force: true)
        end
        GT::Commands::Restack.run([])
      end
    end
  end
end
