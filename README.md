# xr

`xr` is a small CLI that removes friction from the Exercism Ruby workflow.

It remembers the current exercise, runs commands from the right exercise directory, opens your editor, starts IRB with the solution file loaded, runs tests, and submits the solution file without requiring manual `cd` work.

## Install

For the private `hvpaiva/xr` repository, authenticate GitHub CLI first:

```bash
gh auth login
```

Then install with one command:

```bash
sh -c 'set -eu; script=$(gh api -H "Accept: application/vnd.github.raw" repos/hvpaiva/xr/contents/install.sh); printf "%s\n" "$script" | sh'
```

The installer clones or updates the repository at `~/.local/share/xr` and creates this symlink:

```text
~/.local/bin/xr -> ~/.local/share/xr/bin/xr
```

Make sure `~/.local/bin` is in your `PATH`.

## Requirements

- Ruby 3.2+
- Git
- GitHub CLI (`gh`) for the private one-command install
- Exercism CLI for `xr new` and `xr submit`

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
xr test [exercise]      # run ruby -r minitest/pride *_test.rb
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

Editor commands are split with shell-like quoting, so this works:

```bash
XR_EDITOR="code --wait" xr edit
```

## Update

Run the installer again:

```bash
sh -c 'set -eu; script=$(gh api -H "Accept: application/vnd.github.raw" repos/hvpaiva/xr/contents/install.sh); printf "%s\n" "$script" | sh'
```

## Local Development

```bash
ruby -Ilib:test test/xr_test.rb
ruby -c bin/xr
ruby -c lib/xr.rb
ruby -c lib/xr/*.rb
bin/xr help
```
