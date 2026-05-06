# frozen_string_literal: true

require "shellwords"

module Xr
  class CLI
    COMMANDS = %w[new edit test irb submit use current path list clear help version].freeze

    def self.start(argv, out: $stdout, err: $stderr)
      new(argv, out: out, err: err).start
    end

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @ui = UI.new(out: out, err: err)
      @state = State.new
      @runner = CommandRunner.new(ui: @ui)
      @track = Config.track
      @root = Config.root(@track)
      @resolver = Resolver.new(state: @state, track: @track, root: @root)
    end

    def start
      command = @argv.shift || "help"

      case command
      when "new" then new_command
      when "edit" then edit_command
      when "test" then test_command
      when "irb" then irb_command
      when "submit" then submit_command
      when "use" then use_command
      when "current" then current_command
      when "path" then path_command
      when "list" then list_command
      when "clear" then clear_command
      when "help", "-h", "--help" then help_command
      when "version", "-v", "--version" then version_command
      else
        raise Error, "Unknown command: #{command}. Use `xr help`."
      end

      0
    rescue Error => e
      @ui.error(e.message)
      1
    rescue Interrupt
      @ui.error("Interrupted.")
      130
    end

    private

    def new_command
      exercise = exercise_from_required_arg("new <exercise>", require_existing: false)

      @ui.info("Downloading #{exercise.slug}...")
      @runner.run("exercism", "download", "--track=#{exercise.track}", "--exercise=#{exercise.slug}")
      exercise.ensure_exists!
      save_current(exercise)
      edit_exercise(exercise)
    end

    def edit_command
      edit_exercise(@resolver.resolve(optional_arg))
    end

    def test_command
      exercise = @resolver.resolve(optional_arg)
      test_file = exercise.test_file

      @ui.info("Testing #{exercise.slug}...")
      @runner.run("ruby", "-r", "minitest/pride", test_file, chdir: exercise.path)
    end

    def irb_command
      exercise = @resolver.resolve(optional_arg)
      solution_file = exercise.solution_file

      @ui.info("Opening IRB for #{exercise.slug}...")
      @runner.run("irb", "-r", "./#{solution_file}", "--simple-prompt", chdir: exercise.path)
    end

    def submit_command
      exercise = @resolver.resolve(optional_arg)
      solution_file = exercise.solution_file

      @ui.info("Submitting #{exercise.slug}...")
      @runner.run("exercism", "submit", solution_file, chdir: exercise.path)
    end

    def use_command
      exercise = exercise_from_required_arg("use <exercise>")
      save_current(exercise)
      @ui.success("Current exercise: #{exercise.slug}")
      @ui.command(exercise.path)
    end

    def current_command
      data = @state.load
      raise Error, "No current exercise saved." if data.empty? || blank?(data["exercise"])

      path = data["path"]
      @ui.say(@ui.bold(data.fetch("exercise")))
      @ui.say("track: #{data.fetch('track', @track)}")
      @ui.say("path:  #{path}")
      @ui.say("state: #{@state.path}")
      @ui.warn("The saved directory no longer exists.") if path && !Dir.exist?(path)
    end

    def path_command
      exercise = @resolver.resolve(optional_arg)
      @ui.say(exercise.path)
    end

    def list_command
      raise Error, "Exercise directory not found: #{@root}" unless Dir.exist?(@root)

      current = @state.load["exercise"]
      exercises = Dir.children(@root)
                     .select { |name| File.directory?(File.join(@root, name)) && !name.start_with?(".") }
                     .sort

      if exercises.empty?
        @ui.warn("No exercises downloaded in #{@root}.")
        return
      end

      exercises.each do |slug|
        marker = slug == current ? "*" : " "
        @ui.say("#{marker} #{slug}")
      end
    end

    def clear_command
      @state.clear
      @ui.success("State cleared: #{@state.path}")
    end

    def help_command
      @ui.say(<<~HELP)
        #{@ui.bold('xr')} - Exercism Ruby helper

        Usage:
          xr new <exercise>       download, save as current, and open the editor
          xr edit [exercise]      open the editor for an exercise
          xr test [exercise]      run the exercise test file with minitest/pride
          xr irb [exercise]       open irb -r ./<solution>.rb --simple-prompt
          xr submit [exercise]    submit the solution .rb file
          xr use <exercise>       save a downloaded exercise as current
          xr current              show the current exercise
          xr path [exercise]      print the exercise path
          xr list                 list downloaded exercises
          xr clear                clear saved state

        State:
          #{@state.path}

        Environment:
          XR_ROOT     exercise directory (current: #{@root})
          XR_TRACK    Exercism track (current: #{@track})
          XR_EDITOR   editor used by xr edit/new (default: nvim)
          XR_STATE    TOML state file
      HELP
    end

    def version_command
      @ui.say("xr #{VERSION}")
    end

    def edit_exercise(exercise)
      target = editable_target(exercise)
      editor_args = editor_args_from_config
      raise Error, "Invalid editor in XR_EDITOR/VISUAL/EDITOR." if editor_args.empty?

      @ui.info("Opening #{exercise.slug}...")
      @runner.run(*editor_args, target, chdir: exercise.path)
    end

    def editor_args_from_config
      Shellwords.split(Config.editor)
    rescue ArgumentError => e
      raise Error, "Invalid editor in XR_EDITOR/VISUAL/EDITOR: #{e.message}"
    end

    def editable_target(exercise)
      exercise.solution_file
    rescue Error
      "."
    end

    def save_current(exercise)
      @state.save(track: exercise.track, exercise: exercise.slug, path: exercise.path)
    end

    def exercise_from_required_arg(usage, require_existing: true)
      slug = @argv.shift
      raise Error, "Usage: xr #{usage}" if blank?(slug)
      raise Error, "Too many arguments: #{@argv.join(' ')}" unless @argv.empty?

      Exercise.new(slug: slug, track: @track, root: @root).tap do |exercise|
        exercise.ensure_exists! if require_existing
      end
    end

    def optional_arg
      slug = @argv.shift
      raise Error, "Too many arguments: #{@argv.join(' ')}" unless @argv.empty?

      slug
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
