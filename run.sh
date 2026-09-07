#!/usr/bin/env bash
# Runs Flutter and auto-loads `.env` when present (prod defaults otherwise).
# Usage: ./run.sh   or   ./run.sh -d "iPhone 16"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ARGS=("$@")

if [[ -f .env ]]; then
  echo "==> Using .env ($(grep -E '^BASE_URL=' .env | head -1))"
  exec flutter run --dart-define-from-file=.env "${ARGS[@]}"
else
  echo "==> No .env — using production base URLs"
  exec flutter run "${ARGS[@]}"
fi
