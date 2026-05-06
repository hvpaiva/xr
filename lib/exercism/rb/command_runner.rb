# frozen_string_literal: true

require "shellwords"

module Exercism
  module Rb
    class CommandRunner
      def initialize(ui: UI.new)
        @ui = ui
      end

      def run(*args, chdir: nil)
        printable = Shellwords.join(args)
        printable = "cd #{Shellwords.escape(chdir)} && #{printable}" if chdir
        @ui.command("$ #{printable}")

        ok = if chdir
               Dir.chdir(chdir) { system(*args) }
             else
               system(*args)
             end

        raise Error, "Command failed: #{Shellwords.join(args)}" unless ok

        true
      end
    end
  end
end
