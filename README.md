# xr

`xr` is a small CLI that removes friction from the Exercism Ruby workflow.

It remembers the current exercise, runs commands from the right exercise directory, opens your editor, starts IRB with the solution file loaded, runs tests, and submits the solution file without requiring manual `cd` work.

## Install

Install with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/xr/main/install.rb | ruby
```

The installer clones or updates the repository at `~/.local/share/xr` and creates this symlink:

```text
~/.local/bin/xr -> ~/.local/share/xr/bin/xr
```

It also installs the Exercism CLI into `~/.local/bin/exercism` when `exercism` is not already available.

To skip the Exercism CLI install:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/xr/main/install.rb | ruby - --no-exercism
```

To force-install or update the Exercism CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/xr/main/install.rb | ruby - --with-exercism
```

Make sure `~/.local/bin` is in your `PATH`.

If `~/.local/bin/xr` already exists and points somewhere else, the installer refuses to replace it unless you opt in:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/xr/main/install.rb | XR_INSTALL_OVERWRITE=1 ruby
```

## Requirements

- Ruby 3.2+
- Git
- curl for the one-line install command
- tar when the installer needs to download the Exercism CLI
- Exercism CLI for `xr new` and `xr submit` if you skip automatic install

The installer installs the Exercism binary, but it does not configure your Exercism API token. Configure it separately:

```bash
exercism configure --token=<your-api-token>
```

## Main Flow

```bash
xr new assembly-line
xr test
xr irb
xr edit
xr submit
```

## Commands

```bash
xr new <exercise>       # download, save as current, and open the editor
xr edit [exercise]      # open the editor for an exercise
xr test [exercise]      # run the exercise test file with minitest/pride
xr irb [exercise]       # open irb -r ./<solution>.rb --simple-prompt
xr submit [exercise]    # submit the solution .rb file
xr use <exercise>       # save a downloaded exercise as current
xr current              # show the current exercise
xr path [exercise]      # print the exercise path
xr list                 # list downloaded exercises
xr clear                # clear saved state
```

Exercise resolution priority:

1. Explicit slug, for example `xr test assembly-line`
2. Current working directory when inside `XR_ROOT`
3. Saved state from the previous `xr new` or `xr use`

`xr test` expects a single `*_test.rb` file in the exercise directory and reports an ambiguity if more than one is present.

## State

The current exercise is stored as flat TOML:

```text
~/.local/state/xr/state.toml
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
XR_ROOT=~/exercism/ruby      # exercise directory
XR_TRACK=ruby                # Exercism track
XR_EDITOR=nvim               # editor used by xr new/edit
XR_STATE=~/.local/state/xr/state.toml
```

`xr new` uses `exercism download`, which downloads into the workspace configured in the Exercism CLI. If you customize `XR_ROOT`, configure the Exercism workspace so its track directory matches it, for example `exercism configure --workspace ~/exercism` for `XR_ROOT=~/exercism/ruby`.

Editor commands are split with shell-like quoting, so this works:

```bash
XR_EDITOR="code --wait" xr edit
```

## Update

Run the installer again:

```bash
curl -fsSL https://raw.githubusercontent.com/hvpaiva/xr/main/install.rb | ruby
```

## Local Development

```bash
ruby -Ilib:test test/xr_test.rb
ruby -c install.rb
ruby -c bin/xr
ruby -c lib/xr.rb
ruby -c lib/xr/*.rb
bin/xr help
```
