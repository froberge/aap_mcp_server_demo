#!/usr/bin/env bash
#
# Write AAP OAuth/PAT token into Cursor mcp.json (all toolset entries).
#
# Usage:
#   export MY_AAP_SERVICE_TOKEN='<token-from-aap-ui>'
#   ./scripts/set-cursor-mcp-token.sh
#
set -euo pipefail

INPUT="${INPUT:-examples/cursor-mcp.generated.json}"
OUTPUT="${OUTPUT:-${HOME}/.cursor/mcp.json}"

if [[ -z "${MY_AAP_SERVICE_TOKEN:-}" ]]; then
  echo "ERROR: export MY_AAP_SERVICE_TOKEN='<token-from-aap-ui>'" >&2
  exit 1
fi

if [[ ! -f "${INPUT}" ]]; then
  echo "ERROR: Input file not found: ${INPUT}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT}")"

python3 - "${INPUT}" "${OUTPUT}" "${MY_AAP_SERVICE_TOKEN}" <<'PY'
import json
import sys

src, dest, token = sys.argv[1:4]

with open(src, encoding="utf-8") as fh:
    data = json.load(fh)

for entry in data.get("mcpServers", {}).values():
    entry.setdefault("headers", {})["Authorization"] = f"Bearer {token}"

with open(dest, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")

print(f"Wrote {dest}")
PY
