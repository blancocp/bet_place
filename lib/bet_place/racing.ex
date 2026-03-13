defmodule BetPlace.Racing do
  @moduledoc "Context for courses, races, horses, jockeys, trainers, and runners."

  import Ecto.Query
  alias BetPlace.Repo
  alias BetPlace.Racing.{Course, Race, Horse, Jockey, Trainer, Runner, RunnerReplacement}

  # ── Courses ──────────────────────────────────────────────────────────────

  def list_courses do
    Repo.all(from c in Course, where: c.active == true, order_by: c.name)
  end

  def get_course!(id), do: Repo.get!(Course, id)

  def get_course_by_external_id(external_id) do
    Repo.get_by(Course, external_id: external_id)
  end

  def upsert_course(attrs) do
    case get_course_by_external_id(attrs[:external_id] || attrs["external_id"]) do
      nil ->
        %Course{} |> Course.changeset(attrs) |> Repo.insert()

      course ->
        {:ok, course}
    end
  end

  # ── Races ─────────────────────────────────────────────────────────────────

  def list_races_for_course(course_id) do
    Race
    |> where([r], r.course_id == ^course_id)
    |> order_by([r], r.post_time)
    |> Repo.all()
  end

  def list_open_races_for_course(course_id) do
    Race
    |> where([r], r.course_id == ^course_id and r.status not in [:canceled, :finished])
    |> order_by([r], r.post_time)
    |> Repo.all()
  end

  def get_race!(id), do: Repo.get!(Race, id)

  def get_race_by_external_id(external_id) do
    Repo.get_by(Race, external_id: external_id)
  end

  def upsert_race(attrs) do
    external_id = attrs[:external_id] || attrs["external_id"]

    case get_race_by_external_id(external_id) do
      nil ->
        %Race{} |> Race.changeset(attrs) |> Repo.insert()

      race ->
        race |> Race.changeset(attrs) |> Repo.update()
    end
  end

  def update_race(%Race{} = race, attrs) do
    race |> Race.changeset(attrs) |> Repo.update()
  end

  # ── Horses ────────────────────────────────────────────────────────────────

  def get_horse_by_external_id(external_id) do
    Repo.get_by(Horse, external_id: external_id)
  end

  def upsert_horse(attrs) do
    external_id = attrs[:external_id] || attrs["external_id"]

    case get_horse_by_external_id(external_id) do
      nil -> %Horse{} |> Horse.changeset(attrs) |> Repo.insert()
      horse -> {:ok, horse}
    end
  end

  # ── Jockeys ───────────────────────────────────────────────────────────────

  def get_or_create_jockey(name) when is_binary(name) do
    case Repo.get_by(Jockey, name: name) do
      nil ->
        %Jockey{} |> Jockey.changeset(%{name: name}) |> Repo.insert()

      jockey ->
        {:ok, jockey}
    end
  end

  # ── Trainers ──────────────────────────────────────────────────────────────

  def get_or_create_trainer(name) when is_binary(name) do
    case Repo.get_by(Trainer, name: name) do
      nil ->
        %Trainer{} |> Trainer.changeset(%{name: name}) |> Repo.insert()

      trainer ->
        {:ok, trainer}
    end
  end

  # ── Runners ───────────────────────────────────────────────────────────────

  def get_runner!(id), do: Repo.get!(Runner, id)

  def get_runner_by_race_and_horse(race_id, horse_id) do
    Repo.get_by(Runner, race_id: race_id, horse_id: horse_id)
  end

  def get_runner_by_race_and_program_number(race_id, program_number) do
    Repo.get_by(Runner, race_id: race_id, program_number: program_number)
  end

  def list_runners_for_race(race_id) do
    Runner
    |> where([r], r.race_id == ^race_id)
    |> order_by([r], r.program_number)
    |> preload([:horse, :jockey, :trainer])
    |> Repo.all()
  end

  def upsert_runner(attrs) do
    race_id = attrs[:race_id] || attrs["race_id"]
    horse_id = attrs[:horse_id] || attrs["horse_id"]

    case get_runner_by_race_and_horse(race_id, horse_id) do
      nil ->
        %Runner{} |> Runner.changeset(attrs) |> Repo.insert()

      runner ->
        runner |> Runner.changeset(attrs) |> Repo.update()
    end
  end

  def update_runner(%Runner{} = runner, attrs) do
    runner |> Runner.result_changeset(attrs) |> Repo.update()
  end

  # ── Runner Replacements ───────────────────────────────────────────────────

  @doc "Returns the last N races for a course not yet canceled, ordered by post_time asc (soonest first)."
  def list_last_races_for_game_event(course_id, limit \\ 6) do
    Race
    |> where([r], r.course_id == ^course_id and r.status in [:scheduled, :open])
    |> order_by([r], asc: r.race_date, asc: r.post_time)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_courses, do: Repo.aggregate(Course, :count)
  def count_races, do: Repo.aggregate(Race, :count)

  def create_runner_replacement(attrs) do
    %RunnerReplacement{}
    |> RunnerReplacement.changeset(attrs)
    |> Repo.insert()
  end

  def list_replacements_for_race(race_id) do
    RunnerReplacement
    |> where([rr], rr.race_id == ^race_id)
    |> preload([:original_runner, :replacement_runner])
    |> Repo.all()
  end
end
