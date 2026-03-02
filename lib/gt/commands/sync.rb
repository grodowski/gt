# frozen_string_literal: true

module GT
  module Commands
    class Sync
      def self.run(_argv)
        origin = GT::Git.main_branch
        current = GT::Git.current_branch

        GT::UI.spinner("Pulling #{origin}") do
          GT::Git.checkout(origin)
          GT::Git.pull
          GT::Git.checkout(current) unless current == origin
        end
        GT::Commands::Restack.run([])
      end
    end
  end
end
