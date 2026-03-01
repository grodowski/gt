# frozen_string_literal: true

require_relative "commands/create"
require_relative "commands/stack"
require_relative "commands/restack"
require_relative "commands/land"

module GT
  module CLI
    RESTACK_ONLY = %w[restack].freeze

    def self.run(argv)
      command = argv.shift

      if command.nil? || command == "--help" || command == "-h"
        puts usage
        return
      end

      state = GT::State.new

      if state.active? && !RESTACK_ONLY.include?(command)
        raise GT::UserError, "A restack is in progress. Run `gt restack --continue` or `gt restack --abort`."
      end

      case command
      when "create"  then GT::Commands::Create.run(argv)
      when "stack"   then GT::Commands::Stack.run(argv)
      when "restack" then GT::Commands::Restack.run(argv)
      when "land"    then GT::Commands::Land.run(argv)
      else
        raise GT::UserError, "Unknown command: #{command}. Run `gt --help` for usage."
      end
    rescue GT::UserError => e
      warn "gt: #{e.message}"
      exit 1
    rescue GT::GitError => e
      warn "gt: git error: #{e.message}"
      exit 2
    end

    def self.usage
      <<~USAGE
        Usage: gt <command> [options]

        Commands:
          create <name> -m <message>   Create a new stacked branch and PR
          stack                        Show the current stack
          restack                      Rebase the stack onto updated parents
          land                         Land the bottom PR and restack

        Options for restack:
          --continue                   Continue after resolving conflicts
          --abort                      Abort an in-progress restack
      USAGE
    end
  end
end
