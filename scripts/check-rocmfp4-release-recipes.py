#!/usr/bin/env python3

import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "docs" / "rocmfp4-release-recipe-map.tsv"
CATALOG_PATH = ROOT / "docs" / "ROCmFP4-RELEASE-RECIPES.md"
FIELDS = [
    "hf_repo",
    "artifact",
    "implementation_family",
    "topology",
    "release_recipe_label",
    "internal_recipe_id",
]
CONTRACTS = {"qwen35": "dense", "qwen35moe": "moe"}
RECIPE_ID_RE = re.compile(
    r"^rocmfp4\.qwen35\.(dense|moe)\.strix-lean\.v[0-9]+$"
)


def fail(message: str) -> None:
    raise SystemExit(f"ROCmFP4 release recipe check failed: {message}")


with MAP_PATH.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle, delimiter="\t")
    if reader.fieldnames != FIELDS:
        fail(f"unexpected columns: {reader.fieldnames!r}")
    rows = list(reader)

catalog = CATALOG_PATH.read_text(encoding="utf-8")
seen = set()

for line_number, row in enumerate(rows, start=2):
    if any(not row[field].strip() for field in FIELDS):
        fail(f"line {line_number} contains an empty field")

    key = (row["hf_repo"], row["artifact"])
    if key in seen:
        fail(f"duplicate artifact mapping on line {line_number}: {key!r}")
    seen.add(key)

    implementation = row["implementation_family"]
    topology = row["topology"]
    if CONTRACTS.get(implementation) != topology:
        fail(f"line {line_number} has an invalid implementation/topology pair")

    match = RECIPE_ID_RE.fullmatch(row["internal_recipe_id"])
    if match is None or match.group(1) != topology:
        fail(f"line {line_number} has an invalid recipe ID")

    if row["artifact"] not in catalog:
        fail(f"line {line_number} artifact is missing from the Markdown catalog")
    if row["internal_recipe_id"] not in catalog:
        fail(f"line {line_number} recipe ID is missing from the Markdown catalog")

if len(rows) != 7:
    fail(f"expected 7 released ROCmFP4 artifacts, found {len(rows)}")

print("ROCmFP4 release recipe check passed (7 artifacts)")
