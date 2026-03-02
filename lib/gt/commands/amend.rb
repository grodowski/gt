# frozen_string_literal: true

module GT
  module Commands
    class Amend
      def self.run(_argv)
        branch = GT::Git.current_branch
        raise GT::UserError, "Cannot amend the main branch." if branch == GT::Git.main_branch

        GT::UI.spinner("Amending #{branch}") do
          GT::Git.add_all
          GT::Git.amend
          GT::Git.push(branch, force: true)
        end
        GT::Commands::Restack.run([])
      end
    end
  end
end
