# exercism-rb

[![Gem Version](https://badge.fury.io/rb/exercism-rb.svg)](https://rubygems.org/gems/exercism-rb)
[![CI](https://github.com/hvpaiva/exercism-rb/actions/workflows/ci.yml/badge.svg)](https://github.com/hvpaiva/exercism-rb/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/hvpaiva/exercism-rb)](LICENSE)
[![Downloads](https://img.shields.io/gem/dt/exercism-rb)](https://rubygems.org/gems/exercism-rb)

`xrb` is a small CLI that removes friction from the Exercism Ruby workflow.

It remembers the current exercise, runs commands from the right exercise directory, opens your editor, starts IRB with the solution file loaded, runs tests, and submits the solution file without requiring manual `cd` work.

This is an independent helper for the Exercism Ruby track, not an official Exercism project.

## Install

Install from RubyGems:

```bash
gem install exercism-rb
```

Make sure your RubyGems executable directory is in your `PATH`, then verify the CLI:

```bash
xrb version
```

To update:

```bash
gem update exercism-rb
```

## Requirements

- Ruby 3.2+
- Exercism CLI for `xrb new` and `xrb submit`
- An editor available on `PATH` and configured through `XRB_EDITOR`, `VISUAL`, or `EDITOR` for `xrb edit` and default `xrb new`

Configure the Exercism CLI separately:

```bash
exercism configure --token=<your-api-token>
```

## Main Flow

```bash
xrb new assembly-line
xrb test
xrb irb
xrb edit
xrb submit
```

## Commands

```bash
xrb new <exercise>       # download, save as current, and open the editor
xrb edit [exercise]      # open the editor for an exercise
xrb test [exercise]      # run configured or selected test files
xrb irb [exercise]       # open irb -r ./<solution>.rb --simple-prompt
xrb submit [exercise]    # submit through the Exercism CLI
xrb use <exercise>       # save a downloaded exercise as current
xrb current              # show the current exercise
xrb path [exercise]      # print the exercise path
xrb list                 # list downloaded exercises
xrb clear                # clear saved state
```

Exercise resolution priority:

1. Explicit slug, for example `xrb test assembly-line`
2. Current working directory when inside `XRB_ROOT`
3. Saved state from the previous `xrb new` or `xrb use`

`xrb test` reads `.exercism/config.json` when available and runs each file listed in `files.test`. Without that config, it preserves the older fallback of requiring a single `*_test.rb` file.

`xrb submit` lets the Exercism CLI choose default solution files when `.exercism/config.json` is present. Without that config, it preserves the older fallback of requiring a single solution `.rb` file.

Both `xrb test` and `xrb submit` accept a repeatable explicit override:

```bash
xrb test --file custom_test.rb
xrb submit two-fer --file two_fer.rb --file helper.rb
```

Use `xrb new <exercise> --no-edit` to download and save the exercise as current without opening an editor.

## Output And Color

`xrb` uses color automatically when stdout is a terminal. It stays plain when output is redirected, piped, or captured by tests.

Color controls:

```bash
XRB_COLOR=auto      # default
XRB_COLOR=always    # force ANSI color
XRB_COLOR=never     # disable ANSI color
NO_COLOR=1          # disable color in auto mode
CLICOLOR_FORCE=1    # force color in auto mode
```

`xrb path` intentionally prints only the resolved path so it can be used in scripts.

## State

The current exercise is stored as flat TOML:

```text
~/.local/state/exercism-rb/state.toml
```

Example:

```toml
track = "ruby"
exercise = "assembly-line"
path = "/home/hvpaiva/exercism/ruby/assembly-line"
updated_at = "2026-05-05T12:00:00Z"
```

## Configuration

```bash
XRB_ROOT=~/exercism/ruby      # exercise directory
XRB_TRACK=ruby                # Exercism track
XRB_EDITOR="code --wait"      # editor used by xrb new/edit
XRB_STATE=~/.local/state/exercism-rb/state.toml
XRB_COLOR=auto                # auto, always, or never
```

`xrb new` uses `exercism download`, which downloads into the workspace configured in the Exercism CLI. If you customize `XRB_ROOT`, configure the Exercism workspace so its track directory matches it, for example `exercism configure --workspace ~/exercism` for `XRB_ROOT=~/exercism/ruby`.

Set `XRB_EDITOR`, `VISUAL`, or `EDITOR` before running `xrb edit` or `xrb new` without `--no-edit`. Editor commands are split with shell-like quoting, so this works:

```bash
XRB_EDITOR="code --wait" xrb edit
```

## Development

Install development dependencies:

```bash
bundle install
```

Run the default test suite:

```bash
bundle exec rake
```

Run the full verification suite:

```bash
bundle exec rake ci
```

The CI task checks syntax, runs tests, runs tests with Ruby warnings enabled, runs required quality checks, smoke-tests the checkout executable, builds the gem, installs it into an isolated `GEM_HOME`, and smoke-tests the installed `xrb` executable.

Useful individual tasks:

```bash
bundle exec rake test
bundle exec rake syntax
bundle exec rake warnings
bundle exec rake style
bundle exec rake audit
bundle exec rake quality
bundle exec rake coverage
bundle exec rake smoke:bin
bundle exec rake smoke:gem
```

Optional maintenance reports:

```bash
bundle exec rake smells
bundle exec rake critic
```

`bundle exec rake critic` writes its report to `tmp/rubycritic/`, which is ignored by Git.

## Release

Release process details are maintainer documentation and live in `CONTRIBUTING.md`.
