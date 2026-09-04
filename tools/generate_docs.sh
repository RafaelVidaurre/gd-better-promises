#!/usr/bin/env bash
# Regenerates docs/reference from GDScript doc comments.
# Uses the official Godot doctool, then renders the XML as Markdown.
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repository_root"

xml_root=$(mktemp -d)
trap 'rm -rf "$xml_root"' EXIT
mkdir -p "$xml_root/gdb_promise"

# Import the project once so script classes resolve.
ug exec -- --headless --editor --path . --quit

ug exec -- --headless --path . --doctool "$xml_root/gdb_promise" --gdscript-docs res://addons/gdb_promise --quit

rm -rf docs/reference
python3 tools/xml_to_md.py docs/reference "GdbPromise=$xml_root/gdb_promise"

echo "Wrote docs/reference"
