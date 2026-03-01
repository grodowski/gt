# frozen_string_literal: true

module GT
  module Commands
    class Stack
      def self.run(_argv)
        GT::Stack.print
      end
    end
  end
end
