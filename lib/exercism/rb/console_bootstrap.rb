# frozen_string_literal: true

module Exercism
  module Rb
    module ConsoleBootstrap
      FATAL_EXCEPTIONS = [Interrupt, SystemExit].freeze

      module_function

      def install(solution_file: ENV.fetch("XRB_CONSOLE_SOLUTION_FILE"))
        @solution_file = solution_file
        @solution_path = File.expand_path(solution_file, Dir.pwd)

        reload_solution
        $stdout.puts("Run reload! after editing #{solution_file} to reload it.")
      end

      def reload_solution
        load solution_path
        $stdout.puts("Loaded #{solution_file}.")
        true
      rescue Exception => error # rubocop:disable Lint/RescueException
        raise if fatal_exception?(error)

        warn_load_failure(error)
        false
      end

      def solution_file
        @solution_file
      end

      def solution_path
        @solution_path
      end

      def fatal_exception?(error)
        FATAL_EXCEPTIONS.any? { |exception_class| error.is_a?(exception_class) }
      end

      def warn_load_failure(error)
        warn("Could not load #{solution_file}. Fix it and run reload!.")
        warn("#{error.class}: #{error.message}")
        Array(error.backtrace).first(5).each { |line| warn("  #{line}") }
      end
    end
  end
end

def reload!
  Exercism::Rb::ConsoleBootstrap.reload_solution
end

Exercism::Rb::ConsoleBootstrap.install
