#!/usr/bin/env zsh
set -euo pipefail
setopt typesetsilent

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
resolved_file="$repo_root/Modules/Package.resolved"
checkouts_dir="$repo_root/Modules/.build/checkouts"
resource_output_file="$repo_root/Modules/AppFeature/Resources/ACKNOWLEDGEMENTS.md"
output_file="${1:-$resource_output_file}"
agents_file="$repo_root/AGENTS.md"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

if [[ ! -f "$resolved_file" ]]; then
  echo "error: missing $resolved_file" >&2
  exit 1
fi

origin_hash="$(jq -r '.originHash // empty' "$resolved_file")"
if [[ -z "$origin_hash" ]]; then
  echo "error: unable to read originHash from $resolved_file" >&2
  exit 1
fi

if [[ ! -d "$checkouts_dir" ]]; then
  echo "error: missing $checkouts_dir" >&2
  echo "hint: build the package once so SPM checkouts are available" >&2
  exit 1
fi

license_patterns=(
  "LICENSE"
  "LICENSE.md"
  "LICENSE.txt"
  "COPYING"
  "COPYING.txt"
)

find_license_file() {
  local dir="$1"
  local pattern=""
  for pattern in "${license_patterns[@]}"; do
    local candidate=""
    candidate="$(find "$dir" -maxdepth 2 -type f -iname "$pattern" | head -n 1 || true)"
    if [[ -n "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

find_checkout_dir() {
  local identity="$1"
  local candidate=""
  for candidate in "$checkouts_dir"/*; do
    [[ -d "$candidate" ]] || continue
    if [[ "${${candidate:t}:l}" == "${identity:l}" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

mkdir -p "$(dirname "$output_file")"

{
  echo "# Third-Party Acknowledgements"
  echo
  echo "Generated from hash: $origin_hash"
  echo
} > "$output_file"

jq -r '.pins[] | [.identity, .location, .state.version, .state.revision] | @tsv' "$resolved_file" \
  | sort \
  | while IFS=$'\t' read -r identity location version revision; do
    checkout_dir="$(find_checkout_dir "$identity" || true)"

    {
      echo "## $identity"
      echo
      echo "- Repository: $location"
      echo "- Version: $version"
      echo "- Revision: $revision"
    } >> "$output_file"

    if [[ -z "$checkout_dir" ]]; then
      {
        echo "- License: Not found in local SPM checkouts"
        echo
      } >> "$output_file"
      continue
    fi

    license_file="$(find_license_file "$checkout_dir" || true)"
    if [[ -z "$license_file" ]]; then
      {
        echo "- License: Not found in local checkout"
        echo
      } >> "$output_file"
      continue
    fi

    {
      echo '```text'
      sed 's/\r$//' "$license_file"
      echo '```'
      echo
    } >> "$output_file"
  done

echo "Wrote $output_file"

if [[ -f "$agents_file" ]]; then
  tmp_agents_file="$(mktemp)"
  if awk -v hash="$origin_hash" '
    {
      if ($0 ~ /^  - Last acknowledged `originHash`: `[^`]+`$/) {
        print "  - Last acknowledged `originHash`: `" hash "`"
        replaced = 1
      } else {
        print
      }
    }
    END {
      if (!replaced) {
        exit 2
      }
    }
  ' "$agents_file" > "$tmp_agents_file"; then
    mv "$tmp_agents_file" "$agents_file"
    echo "Updated $agents_file originHash note"
  else
    rm -f "$tmp_agents_file"
    echo "warning: could not find originHash note line in $agents_file; skipped update" >&2
  fi
fi
