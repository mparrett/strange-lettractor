#!/usr/bin/env bash
# Every test namespace in its own process, one summary line each, so a
# namespace that dies on load is reported instead of taking the run with it.
# Driven by `lgx runners`; each namespace goes through `lgx test-ns`, which
# owns the runtime and the source paths.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
for file in test/attractor/*_test.lg; do
  ns="attractor.$(basename "$file" .lg | tr _ -)"
  printf '%-52s ' "$ns"
  out=$(lgx test-ns "$ns" 2>&1 | grep -E -m1 '^\{:error')
  echo "${out:-no summary line (load or runtime error)}"
  case "$out" in
    *":error 0, :fail 0,"*) ;;
    *) fail=1 ;;
  esac
done
exit $fail
