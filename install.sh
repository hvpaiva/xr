#!/usr/bin/env sh
set -eu

repo="${XR_REPO:-hvpaiva/xr}"
branch="${XR_BRANCH:-main}"
install_dir="${XR_INSTALL_DIR:-$HOME/.local/share/xr}"
bin_dir="${XR_BIN_DIR:-$HOME/.local/bin}"
bin_path="$bin_dir/xr"

die() {
  printf '%s\n' "xr install: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

safe_install_dir() {
  case "$install_dir" in
    ""|"/"|"$HOME") die "refusing unsafe install directory: $install_dir" ;;
  esac
}

safe_overwrite_dir() {
  safe_install_dir
  case "$install_dir" in
    */xr) ;;
    *) die "refusing to overwrite non-xr directory: $install_dir" ;;
  esac
}

need git
need ruby
safe_install_dir

mkdir -p "$bin_dir"
mkdir -p "$(dirname "$install_dir")"

if [ -d "$install_dir/.git" ]; then
  if [ -f "$install_dir/.git/shallow" ]; then
    git -C "$install_dir" fetch --unshallow origin "$branch"
  else
    git -C "$install_dir" fetch origin "$branch"
  fi
  git -C "$install_dir" checkout -q "$branch"
  git -C "$install_dir" pull --ff-only origin "$branch"
elif [ -e "$install_dir" ]; then
  if [ "${XR_INSTALL_OVERWRITE:-}" = "1" ]; then
    safe_overwrite_dir
    rm -rf "$install_dir"
  else
    die "$install_dir already exists and is not a git checkout. Set XR_INSTALL_OVERWRITE=1 to replace it."
  fi
fi

if [ ! -d "$install_dir/.git" ]; then
  if command -v gh >/dev/null 2>&1; then
    gh repo clone "$repo" "$install_dir" -- --branch "$branch"
  else
    git clone --branch "$branch" "git@github.com:$repo.git" "$install_dir"
  fi
fi

chmod +x "$install_dir/bin/xr"
ln -sf "$install_dir/bin/xr" "$bin_path"

printf '%s\n' "xr installed at $bin_path"
"$bin_path" version

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf '%s\n' "Warning: $bin_dir is not in PATH." >&2 ;;
esac
