#!/bin/sh
# Scaffold a demo target as its OWN git repository (the loop branches and
# resets, so it must never run inside another project's repo).
#   sh new-target.sh lg-primes /tmp/ar-lg     then follow the printed steps
set -eu
kit=$(cd "$(dirname "$0")" && pwd)
name=${1:?target name: lg-primes | py-primes}; dest=${2:?destination directory}
[ -d "$kit/targets/$name" ] || { echo "unknown target $name" >&2; exit 2; }
[ ! -e "$dest" ] || { echo "$dest already exists" >&2; exit 1; }
mkdir -p "$dest/autoresearch"
for file in "$kit/targets/$name"/*; do [ -f "$file" ] && cp "$file" "$dest/"; done
cp "$kit/ar.sh" "$kit/autoresearch.dot" "$kit/program.md" "$dest/autoresearch/"
cd "$dest"
git init -q && git add -A && git commit -q -m "autoresearch target: $name"
echo "created $dest"
echo "  cd $dest && attractor run autoresearch/autoresearch.dot --logs-root attractor_runs"
