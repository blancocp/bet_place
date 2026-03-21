#!/usr/bin/env bash
set -euo pipefail

echo "Applying results seed for today..."
mix run priv/repo/seeds/results_today.exs

echo "Done."
