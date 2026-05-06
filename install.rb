#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "openssl"
require "rbconfig"
require "tmpdir"
require "uri"

class ExercismRbInstaller
  class Error < StandardError; end

  DEFAULT_REPO = "hvpaiva/exercism-rb"
  DEFAULT_BRANCH = "main"
  DEFAULT_INSTALL_EXERCISM = "auto"

  def self.start(argv)
    new(argv).run
  rescue Error => e
    warn_message(e.message)
    1
  end

  def self.warn_message(message)
    $stderr.puts("xrb install: #{message}")
  end

  def initialize(argv)
    @argv = argv.dup
    @repo = ENV.fetch("XRB_REPO", DEFAULT_REPO)
    @branch = ENV.fetch("XRB_BRANCH", DEFAULT_BRANCH)
    @repo_url_explicit = ENV.key?("XRB_REPO_URL")
    @repo_url = ENV.fetch("XRB_REPO_URL", "https://github.com/#{@repo}.git")
    @install_dir = ENV.fetch("XRB_INSTALL_DIR", File.join(Dir.home, ".local", "share", "exercism-rb"))
    @bin_dir = ENV.fetch("XRB_BIN_DIR", File.join(Dir.home, ".local", "bin"))
    @install_exercism = ENV.fetch("XRB_INSTALL_EXERCISM", DEFAULT_INSTALL_EXERCISM)
    @exercism_version = ENV.fetch("XRB_EXERCISM_VERSION", "latest")
    @overwrite = ENV["XRB_INSTALL_OVERWRITE"] == "1"
    @tmp_dir = nil
  end

  def run
    parse_args
    expand_paths

    if @show_help
      puts usage
      return 0
    end

    Dir.mktmpdir("xrb-install.") do |tmp_dir|
      @tmp_dir = tmp_dir
      install_xrb
      maybe_install_exercism
    end

    warn("#{@bin_dir} is not in PATH") unless path_include?(@bin_dir)
    0
  end

  private

  def usage
    <<~USAGE
      exercism-rb installer

      Usage:
        curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | ruby
        curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | ruby - --no-exercism

      Options:
        --repo-url <url>          Git clone URL for exercism-rb
        --branch <name>          Git branch to install (default: main)
        --install-dir <path>     Install checkout path (default: ~/.local/share/exercism-rb)
        --bin-dir <path>         Symlink/bin path (default: ~/.local/bin)
        --with-exercism          Install or update the Exercism CLI
        --no-exercism            Do not install the Exercism CLI
        --exercism-version <v>   Exercism CLI version, for example 3.5.8 or v3.5.8
        -h, --help               Show this help

      Environment:
        XRB_REPO                 GitHub repo slug (default: hvpaiva/exercism-rb)
        XRB_REPO_URL             Full Git clone URL
        XRB_BRANCH               Git branch (default: main)
        XRB_INSTALL_DIR          Install checkout path
        XRB_BIN_DIR              Symlink/bin path
        XRB_INSTALL_EXERCISM     auto, always, or never (default: auto)
        XRB_EXERCISM_VERSION     latest or a specific version (default: latest)
        XRB_INSTALL_OVERWRITE    set to 1 to replace conflicting files/directories
    USAGE
  end

  def parse_args
    until @argv.empty?
      arg = @argv.shift

      case arg
      when "--repo-url"
        @repo_url = required_value(arg)
        @repo_url_explicit = true
      when /^--repo-url=(.+)$/
        @repo_url = Regexp.last_match(1)
        @repo_url_explicit = true
      when "--branch"
        @branch = required_value(arg)
      when /^--branch=(.+)$/
        @branch = Regexp.last_match(1)
      when "--install-dir"
        @install_dir = required_value(arg)
      when /^--install-dir=(.+)$/
        @install_dir = Regexp.last_match(1)
      when "--bin-dir"
        @bin_dir = required_value(arg)
      when /^--bin-dir=(.+)$/
        @bin_dir = Regexp.last_match(1)
      when "--with-exercism", "--install-exercism"
        @install_exercism = "always"
      when "--no-exercism"
        @install_exercism = "never"
      when "--exercism-version"
        @exercism_version = required_value(arg)
      when /^--exercism-version=(.+)$/
        @exercism_version = Regexp.last_match(1)
      when "-h", "--help"
        @show_help = true
      else
        raise Error, "unknown option: #{arg}"
      end
    end
  end

  def required_value(option)
    value = @argv.shift
    raise Error, "missing value for #{option}" if value.nil? || value.empty?

    value
  end

  def expand_paths
    raise Error, "refusing unsafe install directory: #{@install_dir}" if @install_dir.to_s.strip.empty?

    @install_dir = File.expand_path(@install_dir)
    @bin_dir = File.expand_path(@bin_dir)
    @bin_path = File.join(@bin_dir, "xrb")
  end

  def install_xrb
    need("git")
    safe_install_dir

    FileUtils.mkdir_p(@bin_dir)
    FileUtils.mkdir_p(File.dirname(@install_dir))

    if Dir.exist?(File.join(@install_dir, ".git"))
      say("updating exercism-rb in #{@install_dir}")
      git("remote", "set-url", "origin", @repo_url) if @repo_url_explicit
      git("fetch", "origin", @branch)
      git("checkout", "-q", @branch)
      git("pull", "--ff-only", "origin", @branch)
    elsif File.exist?(@install_dir)
      replace_existing_install_dir
    end

    unless Dir.exist?(File.join(@install_dir, ".git"))
      say("cloning exercism-rb from #{@repo_url}")
      run!("git", "clone", "--branch", @branch, @repo_url, @install_dir)
    end

    FileUtils.chmod(0o755, File.join(@install_dir, "bin", "xrb"))
    link_xrb
    say("xrb installed at #{@bin_path}")
    run!(@bin_path, "version")
  end

  def replace_existing_install_dir
    unless @overwrite
      raise Error, "#{@install_dir} already exists and is not a git checkout. Set XRB_INSTALL_OVERWRITE=1 to replace it."
    end

    safe_overwrite_dir
    FileUtils.rm_rf(@install_dir)
  end

  def safe_install_dir
    if ["/", Dir.home].include?(@install_dir)
      raise Error, "refusing unsafe install directory: #{@install_dir}"
    end
  end

  def safe_overwrite_dir
    safe_install_dir
    return if File.basename(@install_dir) == "exercism-rb"

    raise Error, "refusing to overwrite non-exercism-rb directory: #{@install_dir}"
  end

  def git(*args)
    run!("git", "-C", @install_dir, *args)
  end

  def link_xrb
    target = File.join(@install_dir, "bin", "xrb")

    if File.symlink?(@bin_path)
      current = File.readlink(@bin_path)
      return if current == target

      unless @overwrite
        raise Error, "#{@bin_path} already points to #{current}. Set XRB_INSTALL_OVERWRITE=1 to replace it."
      end

      FileUtils.rm_f(@bin_path)
    elsif File.directory?(@bin_path)
      raise Error, "refusing to replace directory: #{@bin_path}"
    elsif File.exist?(@bin_path)
      raise Error, "#{@bin_path} already exists. Set XRB_INSTALL_OVERWRITE=1 to replace it." unless @overwrite

      FileUtils.rm_f(@bin_path)
    end

    FileUtils.ln_s(target, @bin_path)
  end

  def maybe_install_exercism
    case @install_exercism
    when "auto"
      if (path = find_command("exercism"))
        say("exercism already installed: #{path}")
      elsif File.exist?(File.join(@bin_dir, "exercism"))
        warn("#{File.join(@bin_dir, 'exercism')} exists but is not in PATH; leaving it untouched")
      else
        install_exercism_cli
      end
    when "always"
      install_exercism_cli
    when "never"
      say("skipping Exercism CLI install")
    else
      raise Error, "invalid XRB_INSTALL_EXERCISM value: #{@install_exercism}"
    end
  end

  def install_exercism_cli
    need("tar")

    os = detect_exercism_os
    arch = detect_exercism_arch
    tag = requested_exercism_tag
    version = tag.delete_prefix("v")
    archive = "exercism-#{version}-#{os}-#{arch}.tar.gz"
    archive_path = File.join(@tmp_dir, archive)
    url = "https://github.com/exercism/cli/releases/download/#{tag}/#{archive}"

    say("installing Exercism CLI #{tag} for #{os}-#{arch}")
    download_file(url, archive_path)
    verify_exercism_checksum(tag, archive, archive_path)
    run!("tar", "-xzf", archive_path, "-C", @tmp_dir)

    source = File.join(@tmp_dir, "exercism")
    raise Error, "downloaded archive did not contain exercism" unless File.file?(source)

    FileUtils.chmod(0o755, source)
    FileUtils.mkdir_p(@bin_dir)
    install_exercism_binary(source)
  end

  def install_exercism_binary(source)
    target = File.join(@bin_dir, "exercism")

    if File.symlink?(target)
      FileUtils.rm_f(target)
    elsif File.directory?(target)
      raise Error, "refusing to replace directory: #{target}"
    elsif File.exist?(target) && @install_exercism != "always" && !@overwrite
      raise Error, "#{target} already exists. Use --with-exercism or set XRB_INSTALL_OVERWRITE=1 to replace it."
    end

    FileUtils.cp(source, target)
    FileUtils.chmod(0o755, target)
    say("exercism installed at #{target}")
  end

  def detect_exercism_os
    case RbConfig::CONFIG.fetch("host_os")
    when /darwin/i then "darwin"
    when /linux/i then "linux"
    when /freebsd/i then "freebsd"
    when /openbsd/i then "openbsd"
    else
      raise Error, "unsupported OS for automatic Exercism install: #{RbConfig::CONFIG.fetch('host_os')}"
    end
  end

  def detect_exercism_arch
    case RbConfig::CONFIG.fetch("host_cpu")
    when /x86_64|amd64/i then "x86_64"
    when /arm64|aarch64/i then "arm64"
    when /i386|i686/i then "i386"
    when /armv5/i then "armv5"
    when /armv6|armv7/i then "armv6"
    when /ppc64/i then "ppc64"
    else
      raise Error, "unsupported architecture for automatic Exercism install: #{RbConfig::CONFIG.fetch('host_cpu')}"
    end
  end

  def requested_exercism_tag
    return latest_exercism_tag if @exercism_version == "latest"

    @exercism_version.start_with?("v") ? @exercism_version : "v#{@exercism_version}"
  end

  def latest_exercism_tag
    release_json = File.join(@tmp_dir, "exercism-release.json")
    download_file("https://api.github.com/repos/exercism/cli/releases/latest", release_json)
    tag = JSON.parse(File.read(release_json)).fetch("tag_name", nil)
    raise Error, "could not determine latest Exercism CLI version" if tag.nil? || tag.empty?

    tag
  rescue JSON::ParserError
    raise Error, "could not parse latest Exercism CLI release metadata"
  end

  def verify_exercism_checksum(tag, archive, archive_path)
    checksums = File.join(@tmp_dir, "exercism_checksums.txt")
    download_file("https://github.com/exercism/cli/releases/download/#{tag}/exercism_checksums.txt", checksums)

    line = File.readlines(checksums).find do |candidate|
      candidate.split.any? { |part| File.basename(part) == archive }
    end
    raise Error, "checksum not found for #{archive}" if line.nil?

    expected = line.split.first
    actual = Digest::SHA256.file(archive_path).hexdigest
    raise Error, "checksum mismatch for #{archive}" unless actual == expected
  end

  def download_file(url, target)
    uri = URI(url)
    response = http_get(uri)
    File.binwrite(target, response.body)
  rescue URI::InvalidURIError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Timeout::Error => e
    raise Error, "failed to download #{url}: #{e.message}"
  end

  def http_get(uri, limit = 10)
    raise Error, "too many redirects while downloading #{uri}" if limit <= 0
    raise Error, "refusing non-HTTPS download: #{uri}" unless uri.scheme == "https"

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http_request = Net::HTTP::Get.new(uri)
      http_request["User-Agent"] = "xrb-installer"
      response = http.request(http_request)

      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        location = response["location"]
        raise Error, "redirect without location while downloading #{uri}" if location.nil? || location.empty?

        http_get(URI.join(uri, location), limit - 1)
      else
        raise Error, "failed to download #{uri}: HTTP #{response.code}"
      end
    end
  end

  def need(command)
    return if find_command(command)

    raise Error, "missing required command: #{command}"
  end

  def find_command(command)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
      path = File.join(dir, command)
      return path if File.file?(path) && File.executable?(path)
    end

    nil
  end

  def run!(*args)
    return if system(*args)

    raise Error, "command failed: #{args.join(' ')}"
  end

  def say(message)
    puts("xrb install: #{message}")
  end

  def warn(message)
    $stderr.puts("xrb install: warning: #{message}")
  end

  def path_include?(path)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).include?(path)
  end
end

exit ExercismRbInstaller.start(ARGV) if $PROGRAM_NAME == __FILE__
