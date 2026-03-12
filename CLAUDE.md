# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix setup                  # Install deps, create/migrate DB, build assets
mix phx.server             # Start dev server at localhost:4000
iex -S mix phx.server      # Start server inside IEx
mix test                   # Run all tests (creates/migrates DB automatically)
mix test test/path/file_test.exs  # Run a single test file
mix test --failed          # Re-run only previously failed tests
mix precommit              # compile --warnings-as-errors, format, test — run before committing
mix ecto.reset             # Drop and recreate the database
mix ecto.gen.migration name_with_underscores  # Generate a migration
```

## Architecture

This is a standard **Phoenix 1.8 + LiveView** application (Elixir ~> 1.15).

- `lib/bet_place/` — business logic, Ecto schemas, contexts, Repo
- `lib/bet_place_web/` — Phoenix web layer: router, controllers, LiveViews, components
- `lib/bet_place_web/components/core_components.ex` — shared UI components (`<.input>`, `<.icon>`, etc.) imported everywhere via `bet_place_web.ex`
- `lib/bet_place_web/components/layouts.ex` — layout components; all LiveView templates must wrap with `<Layouts.app flash={@flash} ...>`
- `lib/bet_place_web/router.ex` — route definitions; default `:browser` scope is aliased to `BetPlaceWeb`
- `assets/css/app.css` — Tailwind v4 (uses `@import "tailwindcss"` syntax, no `tailwind.config.js`)
- `assets/js/app.js` — JS entrypoint bundled via esbuild
- `priv/repo/migrations/` — Ecto migrations

Key dependencies: `Req` (HTTP client), `Swoosh` (mailer), `Bandit` (HTTP server), `Phoenix.LiveDashboard`.

## Important Guidelines

All guidelines in `AGENTS.md` apply. Key points:

- Use `Req` for HTTP requests — never `:httpoison`, `:tesla`, or `:httpc`
- Run `mix precommit` when done with all changes to catch issues
- Use `mix ecto.gen.migration` (never create migration files manually)
- LiveView templates must start with `<Layouts.app flash={@flash} ...>`
- Use `<.icon name="hero-x-mark">` for icons, never `Heroicons` module directly
- Use `<.input>` component for all form inputs
- Use LiveView streams for collections (never assign raw lists)
- Tailwind v4: never use `@apply` in raw CSS; no `tailwind.config.js`
- No inline `<script>` tags; use colocated hooks (`:type={Phoenix.LiveView.ColocatedHook}`) with `.HookName` convention
- Tests: use `has_element?/2`, `element/2` — never assert against raw HTML strings
