#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP_PATH="$ROOT/docs/rocmfp4-release-recipe-map.tsv"
CATALOG_PATH="$ROOT/docs/ROCmFP4-RELEASE-RECIPES.md"
EXPECTED_HEADER=$'hf_repo\tartifact\timplementation_family\ttopology\trelease_recipe_label\tinternal_recipe_id'

if [[ "$(head -n 1 "$MAP_PATH")" != "$EXPECTED_HEADER" ]]; then
    echo "ROCmFP4 release recipe check failed: unexpected columns" >&2
    exit 1
fi

awk -F '\t' '
    NR == 1 { next }
    NF != 6 { printf "line %d has %d fields, expected 6\n", NR, NF > "/dev/stderr"; failed = 1 }
    $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" || $6 == "" {
        printf "line %d contains an empty field\n", NR > "/dev/stderr"; failed = 1
    }
    $3 == "qwen35" && $4 != "dense" {
        printf "line %d maps qwen35 to a non-dense topology\n", NR > "/dev/stderr"; failed = 1
    }
    $3 == "qwen35moe" && $4 != "moe" {
        printf "line %d maps qwen35moe to a non-MoE topology\n", NR > "/dev/stderr"; failed = 1
    }
    $3 != "qwen35" && $3 != "qwen35moe" {
        printf "line %d has an unknown implementation family\n", NR > "/dev/stderr"; failed = 1
    }
    $6 !~ /^rocmfp4\.qwen35\.(dense|moe)\.strix-lean\.v[0-9]+$/ {
        printf "line %d has an invalid recipe ID\n", NR > "/dev/stderr"; failed = 1
    }
    index($6, "." $4 ".") == 0 {
        printf "line %d recipe ID topology disagrees with its row\n", NR > "/dev/stderr"; failed = 1
    }
    { count++ }
    END {
        if (count != 7) {
            printf "expected 7 released artifacts, found %d\n", count > "/dev/stderr"; failed = 1
        }
        exit failed
    }
' "$MAP_PATH"

duplicates="$(tail -n +2 "$MAP_PATH" | cut -f1,2 | sort | uniq -d)"
if [[ -n "$duplicates" ]]; then
    echo "ROCmFP4 release recipe check failed: duplicate artifact mapping" >&2
    echo "$duplicates" >&2
    exit 1
fi

while IFS=$'\t' read -r _ artifact _ _ _ recipe_id; do
    if ! grep -Fq "$artifact" "$CATALOG_PATH"; then
        echo "ROCmFP4 release recipe check failed: catalog is missing $artifact" >&2
        exit 1
    fi
    if ! grep -Fq "$recipe_id" "$CATALOG_PATH"; then
        echo "ROCmFP4 release recipe check failed: catalog is missing $recipe_id" >&2
        exit 1
    fi
done < <(tail -n +2 "$MAP_PATH")

echo "ROCmFP4 release recipe check passed (7 artifacts)"
