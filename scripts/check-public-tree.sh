#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -d .git ]]; then
  printf 'Run this check after git init and staging the public tree.\n' >&2
  exit 1
fi

tracked="$(git ls-files)"
for forbidden in \
  'docs/tencent-cooperation-inquiry.md' \
  'AGENTS.md' \
  'outputs/' \
  'output/' \
  'dist/' \
  '.build/'
do
  if printf '%s\n' "$tracked" | grep -Fq "$forbidden"; then
    printf 'Forbidden public path is tracked: %s\n' "$forbidden" >&2
    exit 1
  fi
done

if git grep -nEI 'sk-[A-Za-z0-9_-]{12,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' -- . \
  ':(exclude)Tests/ResolveAIMusicTests/ComposerTests.swift'; then
  printf 'Possible credential found in tracked files. Review before publishing.\n' >&2
  exit 1
fi

while IFS= read -r -d '' path; do
  size="$(stat -f '%z' "$path")"
  if (( size > 10485760 )); then
    printf 'Tracked file exceeds 10 MiB: %s\n' "$path" >&2
    exit 1
  fi
done < <(git ls-files -z)

printf 'Public tree check passed.\n'
