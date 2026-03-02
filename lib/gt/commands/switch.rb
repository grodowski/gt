# frozen_string_literal: true

module GT
  module Commands
    class Switch
      def self.run(_argv)
        branches = GT::Stack.build_all
        raise GT::UserError, "No stack found. Use `gt create` to start a stack." if branches.length < 2

        current = GT::Git.current_branch
        target = GT::UI.prompt_select("Switch to branch:", branches)
        GT::Git.checkout(target) unless target == current
      end
    end
  end
end
