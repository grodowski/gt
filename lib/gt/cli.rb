# frozen_string_literal: true

require_relative "commands/create"
require_relative "commands/log"
require_relative "commands/restack"
require_relative "commands/modify"
require_relative "commands/sync"
require_relative "commands/checkout"
require_relative "commands/up"
require_relative "commands/down"
require_relative "commands/top"

module GT
  module CLI
    RESTACK_ONLY = %w[restack].freeze

    def self.gh_installed?
      _, _, status = Open3.capture3("gh --version")
      status.success?
    rescue Errno::ENOENT
      false
    end

    def self.run(argv)
      command = argv.shift

      if command.nil? || command == "--help" || command == "-h"
        puts usage
        return
      end

      unless gh_installed?
        raise GT::UserError, "GitHub CLI (gh) is required but not found. Install it at https://cli.github.com/"
      end

      state = GT::State.new

      if state.active? && !RESTACK_ONLY.include?(command)
        raise GT::UserError, "A restack is in progress. Run `gt restack --continue` or `gt restack --abort`."
      end

      case command
      when "create"          then GT::Commands::Create.run(argv)
      when "log", "ls"       then GT::Commands::Log.run(argv)
      when "restack"         then GT::Commands::Restack.run(argv)
      when "modify", "m"     then GT::Commands::Modify.run(argv)
      when "sync"            then GT::Commands::Sync.run(argv)
      when "checkout", "co"  then GT::Commands::Checkout.run(argv)
      when "up"              then GT::Commands::Up.run(argv)
      when "down"            then GT::Commands::Down.run(argv)
      when "top"             then GT::Commands::Top.run(argv)
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
          create <name> [-m <msg>] [-p] Create a new stacked branch and PR
          log (ls)                     Show the current stack
          restack                      Rebase the stack onto updated parents
                                       (prompts to delete if bottom PR was merged)
          modify (m) [-m <msg>] [-p]   Amend the current branch and restack
          sync                         Pull main and restack

        Navigation:
          up                           Move up one level in the stack
          down                         Move down one level in the stack
          top                          Jump to the top of the stack
          checkout (co) [branch]       Switch to a branch in the stack

        Options for restack:
          --continue                   Continue after resolving conflicts
          --abort                      Abort an in-progress restack
      USAGE
    end
  end
end
