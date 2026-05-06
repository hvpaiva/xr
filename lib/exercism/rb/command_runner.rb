# frozen_string_literal: true

require "shellwords"

module Exercism
  module Rb
    class CommandRunner
      def initialize(ui: UI.new)
        @ui = ui
      end

      def run(*args, chdir: nil, env: {})
        printable = Shellwords.join(args)
        printable = "cd #{Shellwords.escape(chdir)} && #{printable}" if chdir
        @ui.command("$ #{printable}")

        ok = if chdir
          Dir.chdir(chdir) { run_system(env, args) }
        else
          run_system(env, args)
        end

        case ok
        when true
          true
        when nil
          raise Error, "Command not found: #{args.first}. Install it or ensure it is on PATH."
        else
          raise Error, "Command failed: #{Shellwords.join(args)}"
        end

        true
      end

      private

      def run_system(env, args)
        env.empty? ? system(*args) : system(env, *args)
      end
    end
  end
end
