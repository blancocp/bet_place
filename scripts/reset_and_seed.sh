#!/usr/bin/env bash
set -euo pipefail

echo "Resetting database..."
mix ecto.reset

echo "Loading base seeders (without results)..."
mix run priv/repo/seeds.exs

echo "Done."
