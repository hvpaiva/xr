# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.3.0 - 2026-05-06

### Added

- `xrb pry` for opening Pry in the current exercise with the solution loaded and `reload!` available.
- `reload!` helper for both `xrb irb` and `xrb pry` to re-load the exercise solution during an interactive session.

### Changed

- `xrb irb` now loads an xrb console bootstrap instead of requiring the solution file directly, preserving initial load behavior while making iterative reloads explicit and documented.

## 0.2.0 - 2026-05-06

### Added

- Support for `.exercism/config.json` `files.solution` and `files.test` metadata.
- `--no-edit` for `xrb new` to download and save the current exercise without opening an editor.
- Repeatable `--file FILE` overrides for `xrb submit` and `xrb test`.
- Standard, Bundler Audit, Reek, RubyCritic, and opt-in SimpleCov coverage as development quality tools.

### Changed

- `xrb submit` now delegates default file selection to the Exercism CLI when exercise config is available.
- `xrb test` can run multiple configured or explicitly selected test files in order.
- `xrb edit` and `xrb new` now require an explicit editor through `XRB_EDITOR`, `VISUAL`, or `EDITOR` instead of assuming `nvim`.
- CLI status, warning, and error output now uses color without log-style labels.
- Release process details moved from `README.md` to `CONTRIBUTING.md`.

### Removed

- Removed the legacy source installer; RubyGems is now the only supported installation path.

### Fixed

- `xrb new` now explains the likely workspace mismatch when download succeeds but the expected exercise directory is missing.
- Command execution errors now distinguish missing commands from commands that ran and returned a non-zero exit code.

## 0.1.0 - 2026-05-06

### Added

- `xrb` CLI for downloading, selecting, opening, testing, inspecting, and submitting Exercism Ruby exercises.
- Source installer for users who want to install directly from the repository.
- RubyGems release preparation with CI, packaged gem smoke tests, and Trusted Publishing workflow.
- Colorized CLI output with explicit `XRB_COLOR`, `NO_COLOR`, and `CLICOLOR_FORCE` controls.
- Project documentation for development, security, contribution, and release practices.

### Changed

- Installation documentation now treats RubyGems as the primary distribution channel.

### Fixed

- State saves now use `Process.pid` for temporary files, avoiding Ruby warnings from an uninitialized global variable.
