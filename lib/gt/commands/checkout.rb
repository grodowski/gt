# frozen_string_literal: true

module GT
  module Commands
    class Checkout
      def self.run(argv)
        branches = GT::Stack.build_all
        raise GT::UserError, "No stack found. Use `gt create` to start a stack." if branches.length < 2

        current = GT::Git.current_branch
        target = argv.first || GT::UI.prompt_select("Switch to branch:", branches)
        raise GT::UserError, "Branch '#{target}' is not in the stack." unless branches.include?(target)

        GT::Git.checkout(target) unless target == current
      end
    end
  end
end
