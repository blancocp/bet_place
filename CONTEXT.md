# Horse Racing Betting Platform — Claude Code Rules

## Project Overview

Elixir Phoenix LiveView application for horse racing betting games.
Stack: Phoenix LiveView · Tailwind CSS · DaisyUI · PostgreSQL · UUID primary keys.

The platform integrates a third-party horse racing API (USA races) to sync racecards,
race details, and results. It offers two initial betting games: **La Polla** (with
dynamic variant) and **Horse vs Horse**.

---

## Language Rules

- **UI / User-facing text**: Spanish
- **Code, database, comments, variable names, module names, function names**: English
- **Conversations with the developer**: Spanish
- **Error messages in logs**: English
- **Validation messages shown to users**: Spanish

---

## Tech Stack & Versions

```
Elixir ~> 1.15
Phoenix ~> 1.8.5
Phoenix LiveView ~> 1.1.0
Ecto ~> 3.13
PostgreSQL 15+
Tailwind CSS v4 (import syntax, no tailwind.config.js)
DaisyUI (Tailwind v4 plugin via @plugin "../vendor/daisyui")
```

---

## Database Rules

- **All primary keys**: UUID (`binary_id`), never auto-increment integers
- **All foreign keys**: UUID
- Configure in `config/config.exs`:

```elixir
config :my_app, MyApp.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]
```

- Always use `timestamps()` in every schema (gives `inserted_at` / `updated_at`)
- Use `Ecto.UUID` for UUID fields
- Monetary values: `decimal` with precision 15, scale 2 — never `float`
- Enums: define as Ecto custom types or use string columns with `Ecto.Enum`
- Index every foreign key column and every `external_id` field

---

## Project Structure

```
lib/
  my_app/
    racing/          # Context: API sync, courses, races, horses, runners
    games/           # Context: game_types, game_configs, game_events
    betting/         # Context: polla tickets, hvh bets, combinations
    finance/         # Context: transactions, balance management
    accounts/        # Context: users, authentication
    api/             # HTTP client for horse racing API
      client.ex
      parser.ex
      sync_worker.ex
  my_app_web/
    live/
      admin/         # Admin LiveView components
      bettor/        # Bettor-facing LiveView components
    components/
```

---

## Naming Conventions

| Concept (ES) | Code name (EN) |
|---|---|
| Hipódromo | course |
| Carrera | race |
| Caballo | horse |
| Jinete | jockey |
| Entrenador | trainer |
| Participante en carrera | runner |
| Polla hípica | polla |
| Ticket / boleto | ticket |
| Combinación | combination |
| Selección | selection |
| Evento de juego | game_event |
| Enfrentamiento HvH | matchup |
| Apuesta | bet |
| Retiro de caballo | non_runner / withdrawal |
| Reemplazo | replacement |
| Premio | prize |
| Bote total | pool |
| Retención casa | house_cut |

---

## Database Schema

### `users`
```
id              :binary_id, primary key
email           :string, unique, not null
username        :string, unique, not null
password_hash   :string, not null
role            :string  # "admin" | "bettor"
balance         :decimal, default 0.00
status          :string  # "active" | "suspended" | "banned"
confirmed_at    :utc_datetime, nullable
last_login_at   :utc_datetime, nullable
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `courses` (Hipódromos)
```
id              :binary_id, primary key
external_id     :string, unique  # "Aqueduct (USA)" — natural key from API
name            :string          # "Aqueduct"
full_name       :string          # "Aqueduct (USA)"
country         :string          # "USA"
active          :boolean, default true
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `races` (Carreras)
```
id              :binary_id, primary key
external_id     :string, unique  # id_race from API
course_id       :binary_id, FK -> courses
race_date       :date
post_time       :utc_datetime
distance_raw    :string          # "6 furlongs", "1 3/8 miles" — raw from API
distance_meters :integer         # calculated on sync
age_restriction :string          # "2yo", "3yo+", "4yo+"
status          :string          # "scheduled"|"open"|"closed"|"finished"|"canceled"
finished        :boolean, default false
canceled        :boolean, default false
synced_at       :utc_datetime
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `horses`
```
id              :binary_id, primary key
external_id     :string, unique  # id_horse from API
name            :string
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `jockeys`
```
id              :binary_id, primary key
name            :string, unique
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `trainers`
```
id              :binary_id, primary key
name            :string, unique
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `runners` (Participante en carrera — horse + race + jockey + trainer)
```
id              :binary_id, primary key
race_id         :binary_id, FK -> races
horse_id        :binary_id, FK -> horses
jockey_id       :binary_id, FK -> jockeys
trainer_id      :binary_id, FK -> trainers
program_number  :integer         # "number" from API — order in race program
weight          :string          # "8-9"
form            :string          # "5446-"
morning_line    :decimal         # sp from API (starting price)
non_runner      :boolean, default false
position        :integer, nullable  # filled when race finishes
distance_beaten :string, nullable   # "1/2", "13 1/2" — raw from API
inserted_at     :utc_datetime
updated_at      :utc_datetime

UNIQUE INDEX: (race_id, horse_id)
UNIQUE INDEX: (race_id, program_number)
```

### `runner_replacements`
```
id                      :binary_id, primary key
race_id                 :binary_id, FK -> races
original_runner_id      :binary_id, FK -> runners
replacement_runner_id   :binary_id, FK -> runners
reason                  :string  # "non_runner" | "admin_withdrawal"
replaced_by             :binary_id, FK -> users (admin)
replaced_at             :utc_datetime
inserted_at             :utc_datetime
```

### `api_sync_logs`
```
id              :binary_id, primary key
endpoint        :string   # "racecards" | "race" | "results"
external_ref    :string   # id_race or queried date
status          :string   # "ok" | "error"
response_hash   :string   # MD5 to detect changes and avoid reprocessing
error_message   :string, nullable
synced_at       :utc_datetime
```

### `game_types`
```
id              :binary_id, primary key
code            :string  # "polla" | "horse_vs_horse"
name            :string  # "La Polla", "Horse vs Horse"
description     :text
active          :boolean, default true
inserted_at     :utc_datetime
```

### `game_configs`
```
id                  :binary_id, primary key
game_type_id        :binary_id, FK -> game_types
house_cut_pct       :decimal   # e.g. 0.15 = 15%
ticket_value        :decimal   # value per combination (Polla)
min_stake           :decimal   # minimum bet (HvH)
prize_multiplier    :decimal   # e.g. 1.80 for HvH payout
max_horses_per_race :integer   # max selections per race in Polla
active              :boolean, default true
inserted_at         :utc_datetime
updated_at          :utc_datetime
```

### `game_events`
```
id                  :binary_id, primary key
game_type_id        :binary_id, FK -> game_types
game_config_id      :binary_id, FK -> game_configs
course_id           :binary_id, FK -> courses
created_by          :binary_id, FK -> users
name                :string
status              :string  # "draft"|"open"|"closed"|"processing"|"finished"|"canceled"
betting_closes_at   :utc_datetime  # = post_time of first valid race
total_pool          :decimal, default 0.00
house_amount        :decimal, default 0.00
prize_pool          :decimal, default 0.00
canceled_reason     :string, nullable
inserted_at         :utc_datetime
updated_at          :utc_datetime
```

### `game_event_races`
```
id              :binary_id, primary key
game_event_id   :binary_id, FK -> game_events
race_id         :binary_id, FK -> races
race_order      :integer   # 1..6 position within the game
status          :string    # "pending" | "running" | "finished" | "canceled"
inserted_at     :utc_datetime
updated_at      :utc_datetime

UNIQUE INDEX: (game_event_id, race_order)
UNIQUE INDEX: (game_event_id, race_id)
```

### `polla_tickets`
```
id                  :binary_id, primary key
game_event_id       :binary_id, FK -> game_events
user_id             :binary_id, FK -> users
combination_count   :integer
ticket_value        :decimal
total_paid          :decimal
total_points        :integer, nullable   # calculated at the end
rank                :integer, nullable   # final position among all tickets
status              :string  # "active" | "winner" | "loser" | "refunded"
sealed_at           :utc_datetime
inserted_at         :utc_datetime
updated_at          :utc_datetime
```

### `polla_selections`
```
id                    :binary_id, primary key
polla_ticket_id       :binary_id, FK -> polla_tickets
game_event_race_id    :binary_id, FK -> game_event_races
runner_id             :binary_id, FK -> runners   # original user selection
effective_runner_id   :binary_id, FK -> runners   # may differ after replacement
was_replaced          :boolean, default false
points_earned         :integer, default 0   # 0 | 1 | 3 | 5
inserted_at           :utc_datetime
```

### `polla_combinations`
```
id                  :binary_id, primary key
polla_ticket_id     :binary_id, FK -> polla_tickets
combination_index   :integer
total_points        :integer
prize_amount        :decimal, nullable
is_winner           :boolean, default false
inserted_at         :utc_datetime
updated_at          :utc_datetime
```

### `hvh_matchups`
```
id              :binary_id, primary key
game_event_id   :binary_id, FK -> game_events
race_id         :binary_id, FK -> races
created_by      :binary_id, FK -> users
status          :string   # "open" | "closed" | "finished" | "void"
result_side     :string, nullable  # "side_a" | "side_b" | "void"
total_side_a    :decimal, default 0.00
total_side_b    :decimal, default 0.00
total_pool      :decimal, default 0.00
void_reason     :string, nullable
resolved_at     :utc_datetime, nullable
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### `hvh_matchup_sides`
```
id              :binary_id, primary key
hvh_matchup_id  :binary_id, FK -> hvh_matchups
side            :string    # "a" | "b"
runner_id       :binary_id, FK -> runners
inserted_at     :utc_datetime
```

### `hvh_bets`
```
id                  :binary_id, primary key
hvh_matchup_id      :binary_id, FK -> hvh_matchups
user_id             :binary_id, FK -> users
side_chosen         :string    # "a" | "b"
amount              :decimal
potential_payout    :decimal
actual_payout       :decimal, nullable
status              :string   # "pending"|"won"|"lost"|"void"|"refunded"
placed_at           :utc_datetime
inserted_at         :utc_datetime
updated_at          :utc_datetime
```

### `transactions` (Financial ledger — never delete records)
```
id              :binary_id, primary key
user_id         :binary_id, FK -> users
type            :string   # "deposit"|"withdrawal"|"bet"|"payout"|"refund"
amount          :decimal  # always positive
direction       :string   # "credit" | "debit"
reference_type  :string   # "polla_ticket" | "hvh_bet" | "manual" etc.
reference_id    :binary_id, nullable  # polymorphic
balance_before  :decimal  # snapshot at transaction time
balance_after   :decimal  # snapshot at transaction time
status          :string   # "pending" | "completed" | "failed"
description     :string
inserted_at     :utc_datetime
```

---

## API Integration

### Base URL
```
https://horse-racing-usa.p.rapidapi.com
```

### Headers (always required)
```
x-rapidapi-host: horse-racing-usa.p.rapidapi.com
x-rapidapi-key: <secret — store in runtime.exs, never in code>
Content-Type: application/json
```

### Endpoints in consumption order

#### 1. Racecards — GET `/racecards?date=YYYY-MM-DD`
First endpoint consumed each day. Returns scheduled races without runner detail.

**Example response:**
```json
[
  {
    "id_race": "77",
    "course": "Aqueduct (USA)",
    "date": "2020-11-08 16:50:00",
    "distance": "6 furlongs",
    "age": "2yo",
    "finished": "1",
    "canceled": "0"
  },
  {
    "id_race": "78",
    "course": "Aqueduct (USA)",
    "date": "2020-11-08 17:22:00",
    "distance": "1 3/8 miles",
    "age": "3yo+",
    "finished": "1",
    "canceled": "0"
  }
]
```

**Sync logic:**
1. For each item: upsert `courses` by `external_id = course`
2. Upsert `races` by `external_id = id_race`
3. Log to `api_sync_logs`

#### 2. Race Detail — GET `/race/:id_race`
Second endpoint. Called for each `id_race` from step 1. Returns full runner list.

**Example response:**
```json
{
  "id_race": "39302",
  "course": "Parx Racing (USA)",
  "date": "2022-01-18 17:52:00",
  "distance": "1 mile 70 yards",
  "age": "4yo+",
  "finished": "1",
  "canceled": "0",
  "horses": [
    {
      "horse": "WONDER CITY",
      "id_horse": "39950",
      "jockey": "Jaime Rodriguez",
      "trainer": "Cathal A. Lynch",
      "age": "5",
      "weight": "8-9",
      "number": "11",
      "non_runner": "0",
      "form": "5446-",
      "position": "1",
      "distance_beaten": "",
      "sp": "2.1"
    },
    {
      "horse": "RAGAZZA CARINA",
      "id_horse": "9727",
      "jockey": "Silvestre Gonzalez",
      "trainer": "Everton Smith",
      "age": "5",
      "weight": "8-9",
      "number": "9",
      "non_runner": "1",
      "form": "05677560-",
      "position": "",
      "distance_beaten": "",
      "sp": ""
    }
  ]
}
```

**Sync logic:**
1. Upsert `horses` by `external_id = id_horse`
2. Upsert `jockeys` by `name`
3. Upsert `trainers` by `name`
4. Upsert `runners` by `(race_id, horse_id)`
5. If `non_runner == "1"`: set `runners.non_runner = true`, trigger replacement logic
6. If `position` is present and numeric: update `runners.position`

#### 3. Results — GET `/results?date=YYYY-MM-DD`
Third endpoint. Same shape as racecards but only finished races.
Poll periodically (every 60s during race hours) to detect newly finished races.

**Sync logic:**
1. Compare `response_hash` in `api_sync_logs` — skip if unchanged
2. For each finished race not yet processed: fetch detail via `/race/:id`
3. Update `runners.position` and `runners.distance_beaten`
4. Trigger scoring pipeline for any linked `game_event_races`

### Endpoints NOT used (deferred)
- `/horse-stats/:id` — horse result history (useful for UX later, not for game logic)
- `/jockeys-win-rate` — jockey stats
- `/trainers-win-rate` — trainer stats
- `/horses-win-rate` — horse stats

---

## Race Lifecycle & Business Rules

### Step 1 — Course upsert
```
API returns "course": "Aqueduct (USA)"
→ SELECT courses WHERE external_id = "Aqueduct (USA)"
→ If not found: INSERT with name="Aqueduct", country="USA"
→ If found: do nothing
```

### Step 2 — Racecards sync (daily, early morning)
```
GET /racecards?date=today
→ For each race: upsert races by external_id
→ At this point runners are unknown
```

### Step 3 — Race detail sync
```
For each race.external_id from step 2:
  GET /race/:id
  → upsert horses, jockeys, trainers
  → upsert runners (program_number, weight, form, morning_line, non_runner)
```

### Step 4 — Admin creates game event
```
Admin selects: course + game_type
System queries: last 6 races for that course with status != :canceled
Admin confirms → INSERT game_events
System inserts 6 game_event_races (race_order 1..6)
betting_closes_at = MIN(post_time) of the 6 races
game_event.status transitions: :draft → :open
```

### Step 5 — Bettor places polla ticket
```
Bettor selects 1..N horses per race (up to max_horses_per_race)
System computes: combination_count = product of selections per race
total_paid = combination_count * ticket_value
User confirms → debit balance → INSERT polla_ticket + selections + combinations
INSERT transactions (type: "bet", direction: "debit")
```

### Step 6 — Results polling
```
Every 60 seconds during race hours:
  GET /results?date=today
  Compare response_hash
  If changed:
    For each newly finished race:
      GET /race/:id_race
      Update runners.position
      Score linked polla_selections (5/3/1/0 pts)
      Update game_event_races.status = :finished
```

### Step 7 — Special cases

**Non-runner (withdrawn horse):**
```
API sets non_runner = "1" on a runner
→ Find runner with program_number = original.program_number + 1 in same race
→ INSERT runner_replacements
→ UPDATE polla_selections SET effective_runner_id = replacement, was_replaced = true
→ Broadcast LiveView update to all affected bettors
```

**Canceled race:**
```
API sets canceled = "1"
→ UPDATE game_event_races.status = :canceled
→ If game rules require full cancellation:
    UPDATE game_events.status = :canceled
    Refund all polla_tickets for this event
    INSERT transactions (type: "refund", direction: "credit") per user
```

**Tie in race position:**
```
Two runners share position 1 → both get 5pts, position 2 gets 3pts, no 3rd place pts
Two runners share position 2 → both get 3pts, no 3rd place pts
Two runners share position 3 → both get 1pt
```

**Tie in final polla score:**
```
prize_pool / number_of_tied_winners = individual_prize
All tied winners receive equal share
```

### Step 8 — Prize settlement
```
When last game_event_race.status = :finished:
  UPDATE game_events.status = :processing
  For each polla_combination:
    sum points across all selections for that combination
  Identify max_points
  Find all combinations with max_points → winners
  prize_pool = total_pool * (1 - house_cut_pct)
  house_amount = total_pool * house_cut_pct
  individual_prize = prize_pool / winner_count
  For each winner:
    UPDATE polla_combinations.prize_amount = individual_prize, is_winner = true
    UPDATE polla_tickets.status = :winner (or :loser)
    credit user.balance
    INSERT transactions (type: "payout", direction: "credit")
  UPDATE game_events.status = :finished
```

---

## Game Rules Reference

### La Polla Hípica
- Played on the last 6 races of a designated course
- Select 1 or more horses per race
- Points: 1st place = 5pts · 2nd place = 3pts · 3rd place = 1pt
- Multiple selections per race generate multiple combinations
- `total_to_pay = combination_count × ticket_value`
- House retains `house_cut_pct` of total pool
- Remainder split equally among highest-scoring combination(s)
- If a race is canceled → entire game is void → full refund
- Non-runner → replaced by next program number

### Horse vs Horse
- Admin designates 2+ horses (side A vs side B) within a single race
- Bettor picks one side
- Game is valid only if at least one horse from either side finishes in top 5
- If a horse is withdrawn → bet is void → full refund
- Payout = `amount × prize_multiplier` (default 1.80×)
  - Example: bet 1,000 → win 1,800
- House retains `(1 - 1/prize_multiplier)` implicitly via multiplier
- Supports N horses per side (hvh_matchup_sides)

---

## LiveView & UX Rules

- All user-facing text, labels, buttons, error messages: **Spanish**
- Use DaisyUI components: `btn`, `card`, `badge`, `countdown`, `modal`, `alert`, `steps`
- Countdown timer for `betting_closes_at` using LiveView `Process.send_after/3`
- Real-time updates via PubSub topics:
  - `"game_event:{id}"` — race results, replacements, status changes
  - `"user:{id}"` — balance updates, ticket status
- Optimistic UI: show ticket as "procesando..." then confirm via PubSub
- Never show raw UUIDs to users — use human-readable identifiers where needed
- Admin panel: separate layout, protected by role check in `on_mount`

---

## Security Rules

- Passwords: `Bcrypt` via `Bcrypt.hash_pwd_salt/1`
- Auth: `phx_gen_auth` pattern with session tokens
- Admin routes: plug-based role guard, verify on every request
- API key: stored in `runtime.exs` via environment variable `RACING_API_KEY`
- Financial operations: wrap balance debit + transaction insert in `Ecto.Multi`
  to guarantee atomicity — partial updates must never happen
- Rate limit betting endpoints: max 10 tickets per user per minute
- Input validation: all monetary amounts server-side, never trust client values

---

## Ecto Multi Pattern for Financial Operations

Every balance change MUST use `Ecto.Multi`:

```elixir
# Example: place a polla bet
Ecto.Multi.new()
|> Ecto.Multi.run(:check_balance, fn repo, _ ->
  user = repo.get!(User, user_id)
  if user.balance >= total_paid,
    do: {:ok, user},
    else: {:error, :insufficient_balance}
end)
|> Ecto.Multi.insert(:ticket, polla_ticket_changeset)
|> Ecto.Multi.insert_all(:selections, PollaSelection, selections)
|> Ecto.Multi.insert_all(:combinations, PollaCombination, combinations)
|> Ecto.Multi.update(:debit_user, fn %{check_balance: user} ->
  User.balance_changeset(user, %{balance: Decimal.sub(user.balance, total_paid)})
end)
|> Ecto.Multi.insert(:transaction, fn %{check_balance: user, ticket: ticket} ->
  Transaction.changeset(%Transaction{}, %{
    user_id: user_id,
    type: "bet",
    direction: "debit",
    amount: total_paid,
    balance_before: user.balance,
    balance_after: Decimal.sub(user.balance, total_paid),
    reference_type: "polla_ticket",
    reference_id: ticket.id,
    status: "completed"
  })
end)
|> Repo.transaction()
```

---

## API Sync Worker Pattern

```elixir
# Use GenServer + periodic polling
# lib/my_app/api/sync_worker.ex

defmodule MyApp.Api.SyncWorker do
  use GenServer

  @racecards_interval :timer.minutes(30)   # sync racecards every 30 min
  @results_interval   :timer.seconds(60)   # poll results every 60 sec during race hours

  # On startup: sync today's racecards
  # During race hours (configurable): poll results every 60s
  # Always compare response_hash before processing
  # Log every sync attempt to api_sync_logs
end
```

---

## Distance Conversion Reference

Convert `distance_raw` to `distance_meters` on sync:

```
1 furlong = 201.168 meters
"5 furlongs"      → 1006
"5 1/2 furlongs"  → 1107
"6 furlongs"      → 1207
"6 1/2 furlongs"  → 1308
"7 furlongs"      → 1408
"7 1/2 furlongs"  → 1509
"1 mile"          → 1609
"1 mile 70 yards" → 1673
"1 1/16 miles"    → 1710
"1 1/8 miles"     → 1810
"1 3/16 miles"    → 1911
"1 3/8 miles"     → 2414
```

---

## Do Not

- Do not use integer auto-increment IDs anywhere
- Do not store monetary values as `float` — always `decimal`
- Do not perform balance updates outside of `Ecto.Multi`
- Do not expose API keys in source code or version control
- Do not delete `transactions` records — they are an immutable ledger
- Do not use `horse_stats`, `jockey_stats`, or `trainer_stats` endpoints (deferred)
- Do not show internal UUIDs or technical error details to end users
- Do not trust client-side combination counts or amounts — always recompute server-side
