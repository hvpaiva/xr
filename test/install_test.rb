# frozen_string_literal: true

require_relative "test_helper"

class ExercismRbInstallTest < ExercismRbTestCase
  INSTALL_SCRIPT = File.join(PROJECT_ROOT, "install.rb")

  def test_installer_installs_from_local_repo_without_exercism
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "exercism-rb")
      bin_dir = File.join(dir, "bin")
      create_installer_source_repo(source_repo, version: "0.1.0")

      code, out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism",
        extra_env: path_with(bin_dir)
      )

      assert_equal 0, code, err
      assert_includes out, "xrb install: cloning exercism-rb"
      assert_includes out, "xrb installed at #{File.join(bin_dir, 'xrb')}"
      assert_includes out, "xrb 0.1.0"
      refute_includes err, "xrb install: warning"
      assert File.symlink?(File.join(bin_dir, "xrb"))
      assert_equal File.join(install_dir, "bin", "xrb"), File.readlink(File.join(bin_dir, "xrb"))
    end
  end

  def test_installer_updates_existing_checkout
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "exercism-rb")
      bin_dir = File.join(dir, "bin")
      create_installer_source_repo(source_repo, version: "0.1.0")

      code, _out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism",
        extra_env: path_with(bin_dir)
      )
      assert_equal 0, code, err

      write_fake_xrb(File.join(source_repo, "bin", "xrb"), version: "0.2.0")
      git!(source_repo, "add", "bin/xrb")
      git!(source_repo, "-c", "user.name=exercism-rb tests", "-c", "user.email=exercism-rb@example.test", "commit", "-m", "Update fake xrb")

      code, out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism",
        extra_env: path_with(bin_dir)
      )

      assert_equal 0, code, err
      assert_includes out, "xrb install: updating exercism-rb in #{install_dir}"
      assert_includes out, "xrb 0.2.0"
    end
  end

  def test_installer_refuses_existing_xrb_binary_without_overwrite
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "exercism-rb")
      bin_dir = File.join(dir, "bin")
      FileUtils.mkdir_p(bin_dir)
      File.write(File.join(bin_dir, "xrb"), "already here\n")
      create_installer_source_repo(source_repo, version: "0.1.0")

      code, _out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism"
      )

      assert_equal 1, code
      assert_includes err, "#{File.join(bin_dir, 'xrb')} already exists"
      assert_equal "already here\n", File.read(File.join(bin_dir, "xrb"))
    end
  end

  def test_installer_auto_mode_keeps_existing_exercism_in_path
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "exercism-rb")
      bin_dir = File.join(dir, "bin")
      fake_bin = File.join(dir, "fake-bin")
      FileUtils.mkdir_p(fake_bin)
      write_fake_exercism(File.join(fake_bin, "exercism"))
      create_installer_source_repo(source_repo, version: "0.1.0")

      code, out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        extra_env: path_with(fake_bin, bin_dir)
      )

      assert_equal 0, code, err
      assert_includes out, "exercism already installed: #{File.join(fake_bin, 'exercism')}"
      refute File.exist?(File.join(bin_dir, "exercism"))
    end
  end

  def test_installer_refuses_broad_overwrite_directory
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install")
      bin_dir = File.join(dir, "bin")
      FileUtils.mkdir_p(install_dir)
      File.write(File.join(install_dir, "keep"), "do not delete\n")
      create_installer_source_repo(source_repo, version: "0.1.0")

      code, _out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism",
        extra_env: { "XRB_INSTALL_OVERWRITE" => "1" }
      )

      assert_equal 1, code
      assert_includes err, "refusing to overwrite non-exercism-rb directory"
      assert_equal "do not delete\n", File.read(File.join(install_dir, "keep"))
    end
  end

  private

  def run_installer(*args, extra_env: {})
    env = clean_installer_env.merge(extra_env)
    out, err, status = Open3.capture3(env, RUBY, INSTALL_SCRIPT, *args)

    [status.exitstatus, out, err]
  end

  def clean_installer_env
    {
      "XRB_REPO" => nil,
      "XRB_REPO_URL" => nil,
      "XRB_BRANCH" => nil,
      "XRB_INSTALL_DIR" => nil,
      "XRB_BIN_DIR" => nil,
      "XRB_INSTALL_EXERCISM" => nil,
      "XRB_EXERCISM_VERSION" => nil,
      "XRB_INSTALL_OVERWRITE" => nil
    }
  end

  def path_with(*dirs)
    { "PATH" => [*dirs, ENV.fetch("PATH")].join(":") }
  end

  def git_available?
    system("git", "--version", out: File::NULL, err: File::NULL)
  end

  def create_installer_source_repo(path, version:)
    FileUtils.mkdir_p(File.join(path, "bin"))
    write_fake_xrb(File.join(path, "bin", "xrb"), version: version)
    git!(path, "init", "-b", "main")
    git!(path, "add", ".")
    git!(path, "-c", "user.name=exercism-rb tests", "-c", "user.email=exercism-rb@example.test", "commit", "-m", "Initial fake xrb")
  end

  def write_fake_xrb(path, version:)
    File.write(path, <<~SH)
      #!/usr/bin/env sh
      if [ "${1:-}" = "version" ]; then
        printf 'xrb #{version}\n'
      else
        printf 'fake xrb #{version}\n'
      fi
    SH
    File.chmod(0o755, path)
  end

  def write_fake_exercism(path)
    File.write(path, <<~SH)
      #!/usr/bin/env sh
      printf 'fake exercism\n'
    SH
    File.chmod(0o755, path)
  end

  def git!(repo, *args)
    out, err, status = Open3.capture3("git", "-C", repo, *args)

    assert status.success?, "git #{args.join(' ')} failed\nstdout:\n#{out}\nstderr:\n#{err}"
  end
end
