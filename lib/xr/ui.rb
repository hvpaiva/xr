# frozen_string_literal: true

module Xr
  class UI
    COLORS = {
      blue: "\e[34m",
      green: "\e[32m",
      red: "\e[31m",
      yellow: "\e[33m",
      gray: "\e[90m",
      bold: "\e[1m",
      reset: "\e[0m"
    }.freeze

    def initialize(out: $stdout, err: $stderr, color: nil)
      @out = out
      @err = err
      @color = color.nil? ? default_color? : color
    end

    def say(message = "")
      @out.puts(message)
    end

    def info(message)
      @out.puts("#{paint('->', :blue)} #{message}")
    end

    def success(message)
      @out.puts("#{paint('OK', :green)} #{message}")
    end

    def warn(message)
      @err.puts("#{paint('WARN', :yellow)} #{message}")
    end

    def error(message)
      @err.puts("#{paint('ERROR', :red)} #{message}")
    end

    def command(message)
      @out.puts(paint(message, :gray))
    end

    def bold(message)
      paint(message, :bold)
    end

    private

    def default_color?
      @out.tty? && !ENV.key?("NO_COLOR")
    end

    def paint(message, color)
      return message unless @color

      "#{COLORS.fetch(color)}#{message}#{COLORS.fetch(:reset)}"
    end
  end
end
