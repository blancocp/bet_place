import Ecto.Query

alias BetPlace.Repo
alias BetPlace.Games.{GameConfig, GameType}
alias BetPlace.Racing

data_file = Path.expand("data/curated_racing_data.exs", __DIR__)
{payload, _binding} = Code.eval_file(data_file)

today = Date.utc_today()

build_post_time = fn
  nil ->
    nil

  iso_time ->
    with {:ok, time} <- Time.from_iso8601(iso_time),
         {:ok, datetime} <- DateTime.new(today, time, "Etc/UTC") do
      datetime
    else
      _ -> nil
    end
end

# Game types
polla_type =
  Repo.get_by(GameType, code: :polla) ||
    Repo.insert!(%GameType{
      code: :polla,
      name: "La Polla Hípica",
      description: "Juego de combinaciones por carreras",
      active: true
    })

hvh_type =
  Repo.get_by(GameType, code: :horse_vs_horse) ||
    Repo.insert!(%GameType{
      code: :horse_vs_horse,
      name: "Horse vs Horse",
      description: "Juego VS por bloques",
      active: true
    })

unless Repo.one(from gc in GameConfig, where: gc.game_type_id == ^polla_type.id and gc.active == true, limit: 1) do
  Repo.insert!(%GameConfig{
    game_type_id: polla_type.id,
    house_cut_pct: Decimal.new("0.15"),
    ticket_value: Decimal.new("100.00"),
    max_horses_per_race: 3,
    active: true
  })
end

unless Repo.one(from gc in GameConfig, where: gc.game_type_id == ^hvh_type.id and gc.active == true, limit: 1) do
  Repo.insert!(%GameConfig{
    game_type_id: hvh_type.id,
    house_cut_pct: Decimal.new("0.10"),
    min_stake: Decimal.new("50.00"),
    prize_multiplier: Decimal.new("1.80"),
    active: true
  })
end

# Courses
Enum.each(payload.courses, fn course ->
  Racing.upsert_course(course)
end)

# Horses
Enum.each(payload.horses, fn horse ->
  Racing.upsert_horse(horse)
end)

# Races (date remapped to today)
Enum.each(payload.races, fn race ->
  course = Racing.get_course_by_external_id(race.course_external_id)

  Racing.upsert_race(%{
    external_id: race.external_id,
    course_id: course.id,
    race_date: today,
    post_time: build_post_time.(race.post_time_utc),
    distance_raw: race.distance_raw,
    distance_meters: race.distance_meters,
    age_restriction: race.age_restriction,
    status: :scheduled,
    finished: false,
    canceled: false,
    synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
end)

# Runners
Enum.each(payload.runners, fn runner ->
  race = Racing.get_race_by_external_id(runner.race_external_id)
  horse = Racing.get_horse_by_external_id(runner.horse_external_id)

  Racing.upsert_runner(%{
    race_id: race.id,
    horse_id: horse.id,
    program_number: runner.program_number,
    weight: runner.weight,
    form: runner.form,
    morning_line: runner.morning_line,
    non_runner: false,
    position: nil,
    distance_beaten: nil
  })
end)

IO.puts("Base catalog seed loaded for date #{Date.to_string(today)}")
