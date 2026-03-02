# frozen_string_literal: true

module GT
  module Commands
    class Down
      def self.run(_argv)
        branches = GT::Stack.build_all
        current = GT::Git.current_branch
        idx = branches.index(current)
        raise GT::UserError, "Current branch '#{current}' is not in a stack." if idx.nil?
        raise GT::UserError, "Already at the bottom of the stack." if idx == 0

        GT::Git.checkout(branches[idx - 1])
      end
    end
  end
end
