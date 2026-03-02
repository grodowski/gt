# frozen_string_literal: true

require "cli/ui"

module GT
  module UI
    module_function

    def success(message)
      ::CLI::UI.puts("{{green:#{message}}}")
    end

    def info(message)
      ::CLI::UI.puts("{{cyan:#{message}}}")
    end

    def warn(message)
      ::CLI::UI.puts("{{yellow:#{message}}}")
    end

    def spinner(title)
      if $stdout.tty?
        task_error = nil
        ::CLI::UI::SpinGroup.new(auto_debrief: false) do |sg|
          sg.add(title) do
            begin
              yield
            rescue => e
              task_error = e
              raise
            end
          end
        end
        raise task_error if task_error
      else
        yield
      end
    end

    def confirm(message)
      ::CLI::UI.confirm(message)
    end

    def render(template)
      ::CLI::UI.fmt(template)
    end

    def prompt_select(message, options)
      ::CLI::UI.ask(message, options: options)
    end
  end
end
