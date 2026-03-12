# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run multiple times — uses insert_or_ignore for idempotency.

import Ecto.Query
alias BetPlace.Repo
alias BetPlace.Games.{GameType, GameConfig}

# ── Game Types ────────────────────────────────────────────────────────────────

polla_type =
  case Repo.get_by(GameType, code: :polla) do
    nil ->
      Repo.insert!(%GameType{
        code: :polla,
        name: "La Polla Hípica",
        description:
          "Selecciona un caballo por carrera en las últimas 6 carreras del hipódromo. Gana quien acumule más puntos.",
        active: true
      })

    existing ->
      existing
  end

hvh_type =
  case Repo.get_by(GameType, code: :horse_vs_horse) do
    nil ->
      Repo.insert!(%GameType{
        code: :horse_vs_horse,
        name: "Horse vs Horse",
        description:
          "Elige uno de dos caballos en una carrera. Multiplica tu apuesta si gana tu selección.",
        active: true
      })

    existing ->
      existing
  end

IO.puts("Game types seeded: #{polla_type.code}, #{hvh_type.code}")

# ── Game Configs ──────────────────────────────────────────────────────────────

unless Repo.one(
         from gc in GameConfig,
           where: gc.game_type_id == ^polla_type.id and gc.active == true,
           limit: 1
       ) do
  Repo.insert!(%GameConfig{
    game_type_id: polla_type.id,
    house_cut_pct: Decimal.new("0.15"),
    ticket_value: Decimal.new("100.00"),
    max_horses_per_race: 3,
    active: true
  })

  IO.puts("Polla config seeded (15% cut, ticket 100, max 3 horses/race)")
end

unless Repo.one(
         from gc in GameConfig,
           where: gc.game_type_id == ^hvh_type.id and gc.active == true,
           limit: 1
       ) do
  Repo.insert!(%GameConfig{
    game_type_id: hvh_type.id,
    house_cut_pct: Decimal.new("0.10"),
    min_stake: Decimal.new("50.00"),
    prize_multiplier: Decimal.new("1.80"),
    active: true
  })

  IO.puts("HvH config seeded (10% cut, min stake 50, multiplier 1.80x)")
end
