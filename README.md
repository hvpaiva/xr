# exercism-rb

`xrb` is a small CLI that removes friction from the Exercism Ruby workflow.

It remembers the current exercise, runs commands from the right exercise directory, opens your editor, starts IRB with the solution file loaded, runs tests, and submits the solution file without requiring manual `cd` work.

This is an independent helper for the Exercism Ruby track, not an official Exercism project.

## Install

Install with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | ruby
```

The installer clones or updates the repository at `~/.local/share/exercism-rb` and creates this symlink:

```text
~/.local/bin/xrb -> ~/.local/share/exercism-rb/bin/xrb
```

It also installs the Exercism CLI into `~/.local/bin/exercism` when `exercism` is not already available.

To skip the Exercism CLI install:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | ruby - --no-exercism
```

To force-install or update the Exercism CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | ruby - --with-exercism
```

Make sure `~/.local/bin` is in your `PATH`.

If `~/.local/bin/xrb` already exists and points somewhere else, the installer refuses to replace it unless you opt in:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | XRB_INSTALL_OVERWRITE=1 ruby
```

## Requirements

- Ruby 3.2+
- Git
- curl for the one-line install command
- tar when the installer needs to download the Exercism CLI
- Exercism CLI for `xrb new` and `xrb submit` if you skip automatic install

The installer installs the Exercism binary, but it does not configure your Exercism API token. Configure it separately:

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
xrb test [exercise]      # run the exercise test file with minitest/pride
xrb irb [exercise]       # open irb -r ./<solution>.rb --simple-prompt
xrb submit [exercise]    # submit the solution .rb file
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

`xrb test` expects a single `*_test.rb` file in the exercise directory and reports an ambiguity if more than one is present.

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
XRB_EDITOR=nvim               # editor used by xrb new/edit
XRB_STATE=~/.local/state/exercism-rb/state.toml
```

`xrb new` uses `exercism download`, which downloads into the workspace configured in the Exercism CLI. If you customize `XRB_ROOT`, configure the Exercism workspace so its track directory matches it, for example `exercism configure --workspace ~/exercism` for `XRB_ROOT=~/exercism/ruby`.

Editor commands are split with shell-like quoting, so this works:

```bash
XRB_EDITOR="code --wait" xrb edit
```

## Update

Run the installer again:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/exercism-rb/main/install.rb | ruby
```

## Local Development

```bash
ruby -Ilib:test test/exercism_rb_test.rb
ruby -c install.rb
ruby -c bin/xrb
ruby -c lib/exercism/rb.rb
ruby -c lib/exercism/rb/*.rb
bin/xrb help
```
