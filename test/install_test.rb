# frozen_string_literal: true

require_relative "test_helper"

class XrInstallTest < XrTestCase
  INSTALL_SCRIPT = File.join(PROJECT_ROOT, "install.sh")

  def test_install_script_installs_from_local_repo_without_exercism
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "xr")
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
      assert_includes out, "xr install: cloning xr"
      assert_includes out, "xr installed at #{File.join(bin_dir, 'xr')}"
      assert_includes out, "xr 0.1.0"
      refute_includes err, "xr install: warning"
      assert File.symlink?(File.join(bin_dir, "xr"))
      assert_equal File.join(install_dir, "bin", "xr"), File.readlink(File.join(bin_dir, "xr"))
    end
  end

  def test_install_script_updates_existing_checkout
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "xr")
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

      write_fake_xr(File.join(source_repo, "bin", "xr"), version: "0.2.0")
      git!(source_repo, "add", "bin/xr")
      git!(source_repo, "-c", "user.name=xr tests", "-c", "user.email=xr@example.test", "commit", "-m", "Update fake xr")

      code, out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism",
        extra_env: path_with(bin_dir)
      )

      assert_equal 0, code, err
      assert_includes out, "xr install: updating xr in #{install_dir}"
      assert_includes out, "xr 0.2.0"
    end
  end

  def test_install_script_refuses_existing_xr_binary_without_overwrite
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "xr")
      bin_dir = File.join(dir, "bin")
      FileUtils.mkdir_p(bin_dir)
      File.write(File.join(bin_dir, "xr"), "already here\n")
      create_installer_source_repo(source_repo, version: "0.1.0")

      code, _out, err = run_installer(
        "--repo-url", "file://#{source_repo}",
        "--install-dir", install_dir,
        "--bin-dir", bin_dir,
        "--no-exercism"
      )

      assert_equal 1, code
      assert_includes err, "#{File.join(bin_dir, 'xr')} already exists"
      assert_equal "already here\n", File.read(File.join(bin_dir, "xr"))
    end
  end

  def test_install_script_auto_mode_keeps_existing_exercism_in_path
    skip "git is required" unless git_available?

    Dir.mktmpdir do |dir|
      source_repo = File.join(dir, "source")
      install_dir = File.join(dir, "install", "xr")
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

  def test_install_script_refuses_broad_overwrite_directory
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
        extra_env: { "XR_INSTALL_OVERWRITE" => "1" }
      )

      assert_equal 1, code
      assert_includes err, "refusing to overwrite non-xr directory"
      assert_equal "do not delete\n", File.read(File.join(install_dir, "keep"))
    end
  end

  private

  def run_installer(*args, extra_env: {})
    env = clean_installer_env.merge(extra_env)
    out, err, status = Open3.capture3(env, "sh", INSTALL_SCRIPT, *args)

    [status.exitstatus, out, err]
  end

  def clean_installer_env
    {
      "XR_REPO" => nil,
      "XR_REPO_URL" => nil,
      "XR_BRANCH" => nil,
      "XR_INSTALL_DIR" => nil,
      "XR_BIN_DIR" => nil,
      "XR_INSTALL_EXERCISM" => nil,
      "XR_EXERCISM_VERSION" => nil,
      "XR_INSTALL_OVERWRITE" => nil
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
    write_fake_xr(File.join(path, "bin", "xr"), version: version)
    git!(path, "init", "-b", "main")
    git!(path, "add", ".")
    git!(path, "-c", "user.name=xr tests", "-c", "user.email=xr@example.test", "commit", "-m", "Initial fake xr")
  end

  def write_fake_xr(path, version:)
    File.write(path, <<~SH)
      #!/usr/bin/env sh
      if [ "${1:-}" = "version" ]; then
        printf 'xr #{version}\n'
      else
        printf 'fake xr #{version}\n'
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
