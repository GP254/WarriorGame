#!/bin/zsh
set -e
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
engine="$(command -v godot || true)"
if [[ -z "$engine" && -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  engine=/Applications/Godot.app/Contents/MacOS/Godot
fi
if [[ -z "$engine" ]]; then
  print 'Install Godot 4.7.1, then open project.godot and press F5.'
  exit 1
fi
exec "$engine" --path "$project_dir" "$@"
