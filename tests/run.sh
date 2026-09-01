#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
cd "$repo_root"

export XDG_DATA_HOME="$repo_root/.godot/xdg/data"
export XDG_CONFIG_HOME="$repo_root/.godot/xdg/config"
export XDG_CACHE_HOME="$repo_root/.godot/xdg/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

ug exec -- --headless --editor --path . --log-file .godot/editor.log --quit
ug exec -- --headless --path . --log-file .godot/tests.log --script res://addons/gut/gut_cmdln.gd -gexit
