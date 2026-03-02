# frozen_string_literal: true

module GT
  module Commands
    class Top
      def self.run(_argv)
        branches = GT::Stack.build_all
        current = GT::Git.current_branch
        top = branches.last
        raise GT::UserError, "Current branch '#{current}' is not in a stack." unless branches.include?(current)

        if current == top
          GT::UI.info("Already at the top: #{top}")
        else
          GT::Git.checkout(top)
        end
      end
    end
  end
end
