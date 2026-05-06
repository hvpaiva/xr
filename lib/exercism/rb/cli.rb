# frozen_string_literal: true

require "shellwords"

module Exercism
  module Rb
    class CLI
      COMMANDS = %w[new edit test irb submit use current path list clear help version].freeze
      COMMAND_METHODS = {
        "new" => :new_command,
        "edit" => :edit_command,
        "test" => :test_command,
        "irb" => :irb_command,
        "submit" => :submit_command,
        "use" => :use_command,
        "current" => :current_command,
        "path" => :path_command,
        "list" => :list_command,
        "clear" => :clear_command,
        "help" => :help_command,
        "-h" => :help_command,
        "--help" => :help_command,
        "version" => :version_command,
        "-v" => :version_command,
        "--version" => :version_command
      }.freeze

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
        handler = COMMAND_METHODS.fetch(command) { raise Error, "Unknown command: #{command}. Use `xrb help`." }

        __send__(handler)

        0
      rescue Error => error
        @ui.error(error.message)
        1
      rescue Interrupt
        @ui.error("Interrupted.")
        130
      end

      private

      def new_command
        skip_editor = extract_no_edit_option!
        exercise = exercise_from_required_arg("new <exercise>", require_existing: false)

        @ui.info("Downloading #{@ui.highlight(exercise.slug)}...")
        @runner.run("exercism", "download", "--track=#{exercise.track}", "--exercise=#{exercise.slug}")
        ensure_download_created_exercise!(exercise)
        save_current(exercise)
        @ui.key_value("Path", @ui.path(exercise.path))
        edit_exercise(exercise) unless skip_editor
      end

      def edit_command
        edit_exercise(@resolver.resolve(optional_arg))
      end

      def test_command
        files = extract_file_options!
        exercise = @resolver.resolve(optional_arg)
        test_files = files.empty? ? exercise.test_files(ambiguity_hint: "Use --file FILE to choose test files explicitly.") : files
        ensure_test_files_exist!(exercise, test_files)

        @ui.info("Testing #{@ui.highlight(exercise.slug)}...")
        test_files.each do |test_file|
          @runner.run("ruby", "-r", "minitest/pride", test_file, chdir: exercise.path)
        end
      end

      def irb_command
        exercise = @resolver.resolve(optional_arg)
        solution_file = exercise.solution_file

        @ui.info("Opening IRB for #{@ui.highlight(exercise.slug)}...")
        @runner.run("irb", "-r", "./#{solution_file}", "--simple-prompt", chdir: exercise.path)
      end

      def submit_command
        files = extract_file_options!
        exercise = @resolver.resolve(optional_arg)

        @ui.info("Submitting #{@ui.highlight(exercise.slug)}...")
        if files.empty? && exercise.exercism_config?
          @runner.run("exercism", "submit", chdir: exercise.path)
        else
          files = [exercise.solution_file(ambiguity_hint: "Use --file FILE to choose files explicitly.")] if files.empty?
          @runner.run("exercism", "submit", *files, chdir: exercise.path)
        end
      end

      def use_command
        exercise = exercise_from_required_arg("use <exercise>")
        save_current(exercise)
        @ui.success("Current exercise: #{@ui.highlight(exercise.slug)}")
        @ui.command(@ui.path(exercise.path))
      end

      def current_command
        data = @state.load
        raise Error, "No current exercise saved." if data.empty? || blank?(data["exercise"])

        path = data["path"]
        @ui.title("Current exercise")
        @ui.key_value("Exercise", @ui.highlight(data.fetch("exercise")))
        @ui.key_value("Track", data.fetch("track", @track))
        @ui.key_value("Path", @ui.path(path))
        @ui.key_value("State", @ui.path(@state.path))
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

        @ui.section("Downloaded exercises")
        exercises.each do |slug|
          marker = (slug == current) ? "*" : " "
          label = (slug == current) ? @ui.highlight(slug) : slug
          suffix = (slug == current) ? " #{@ui.muted("current")}" : ""
          @ui.say("#{marker} #{label}#{suffix}")
        end
      end

      def clear_command
        @state.clear
        @ui.success("State cleared: #{@state.path}")
      end

      def help_command
        @ui.say(<<~HELP)
          #{@ui.bold("xrb")} - Exercism Ruby helper

          Usage:
            xrb new <exercise>       download, save as current, and open the editor
            xrb edit [exercise]      open the editor for an exercise
            xrb test [exercise]      run exercise tests with minitest/pride
            xrb irb [exercise]       open irb -r ./<solution>.rb --simple-prompt
            xrb submit [exercise]    submit the exercise solution
            xrb use <exercise>       save a downloaded exercise as current
            xrb current              show the current exercise
            xrb path [exercise]      print the exercise path
            xrb list                 list downloaded exercises
            xrb clear                clear saved state

          Options:
            --no-edit               skip opening the editor after xrb new
            --file FILE              test or submit an explicit file; may be repeated

          State:
            #{@state.path}

          Environment:
            XRB_ROOT     exercise directory (current: #{@root})
            XRB_TRACK    Exercism track (current: #{@track})
            XRB_EDITOR   editor used by xrb edit/new
            XRB_STATE    TOML state file
            XRB_COLOR    color output: auto, always, or never
        HELP
      end

      def version_command
        @ui.say("xrb #{VERSION}")
      end

      def edit_exercise(exercise)
        target = editable_target(exercise)
        editor_args = editor_args_from_config
        raise Error, "Invalid editor in XRB_EDITOR/VISUAL/EDITOR." if editor_args.empty?
        ensure_editor_available!(editor_args.first, chdir: exercise.path)

        @ui.info("Opening #{@ui.highlight(exercise.slug)}...")
        @runner.run(*editor_args, target, chdir: exercise.path)
      end

      def ensure_download_created_exercise!(exercise)
        return if exercise.exists?

        raise Error, <<~MESSAGE.chomp
          Download completed, but xrb could not find the expected exercise directory:
          #{exercise.path}

          The Exercism CLI probably downloaded to another workspace. Configure it to match XRB_ROOT:
          exercism configure --workspace #{File.dirname(@root)}
        MESSAGE
      end

      def ensure_test_files_exist!(exercise, test_files)
        test_files.each do |file|
          next if File.file?(File.absolute_path(file, exercise.path))

          raise Error, "Test file not found: #{file}"
        end
      end

      def extract_file_options!
        files = []
        remaining = []

        until @argv.empty?
          arg = @argv.shift

          case arg
          when "--file"
            value = @argv.shift
            raise Error, "Missing value for --file" if blank?(value)

            files << value
          when /\A--file=(.*)\z/
            value = Regexp.last_match(1)
            raise Error, "Missing value for --file" if blank?(value)

            files << value
          else
            raise Error, "Unknown option: #{arg}" if arg.start_with?("-")

            remaining << arg
          end
        end

        @argv = remaining
        files
      end

      def extract_no_edit_option!
        skip_editor = false
        remaining = []

        until @argv.empty?
          arg = @argv.shift

          if arg == "--no-edit"
            skip_editor = true
          else
            raise Error, "Unknown option: #{arg}" if arg.start_with?("-")

            remaining << arg
          end
        end

        @argv = remaining
        skip_editor
      end

      def editor_args_from_config
        editor = Config.editor
        raise Error, "No editor configured. Set XRB_EDITOR, VISUAL, or EDITOR." if blank?(editor)

        Shellwords.split(editor)
      rescue ArgumentError => error
        raise Error, "Invalid editor in XRB_EDITOR/VISUAL/EDITOR: #{error.message}"
      end

      def ensure_editor_available!(command, chdir:)
        return if editor_command_available?(command, chdir: chdir)

        raise Error, "Editor not found: #{command}. Set XRB_EDITOR, VISUAL, or EDITOR to an installed executable."
      end

      def editor_command_available?(command, chdir:)
        if command_path?(command)
          return executable_file?(File.absolute_path(command, chdir))
        end

        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          candidate_dir = dir.empty? ? "." : dir
          executable_file?(File.absolute_path(File.join(candidate_dir, command), chdir))
        end
      end

      def command_path?(command)
        command.include?(File::SEPARATOR) || (File::ALT_SEPARATOR && command.include?(File::ALT_SEPARATOR))
      end

      def executable_file?(path)
        File.file?(path) && File.executable?(path)
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
        raise Error, "Usage: xrb #{usage}" if blank?(slug)
        raise Error, "Too many arguments: #{@argv.join(" ")}" unless @argv.empty?

        Exercise.new(slug: slug, track: @track, root: @root).tap do |exercise|
          exercise.ensure_exists! if require_existing
        end
      end

      def optional_arg
        slug = @argv.shift
        raise Error, "Too many arguments: #{@argv.join(" ")}" unless @argv.empty?

        slug
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
