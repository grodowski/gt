# frozen_string_literal: true

module GT
  module Commands
    class Log
      def self.run(_argv)
        GT::Stack.print
      end
    end
  end
end
