# frozen_string_literal: true

require "json"

module GT
  class State
    FILE_NAME = "gt-restack-state"

    def initialize
      @path = File.join(GT::Git.git_dir, FILE_NAME)
    end

    def active?
      File.exist?(@path)
    end

    def save(data)
      File.write(@path, JSON.generate(data))
    end

    def load
      return nil unless active?

      JSON.parse(File.read(@path), symbolize_names: true)
    end

    def clear
      File.delete(@path) if active?
    end
  end
end
