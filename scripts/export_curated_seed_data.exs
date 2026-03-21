import Ecto.Query

alias BetPlace.Repo
alias BetPlace.Racing.{Race, Runner}

target_dir = Path.expand("../priv/repo/seeds/data", __DIR__)
File.mkdir_p!(target_dir)

races_with_results =
  Race
  |> where([r], r.finished == true)
  |> join(:inner, [r], ru in Runner, on: ru.race_id == r.id and not is_nil(ru.position))
  |> distinct([r], r.id)
  |> preload([:course, runners: :horse])
  |> Repo.all()

courses =
  races_with_results
  |> Enum.map(& &1.course)
  |> Enum.uniq_by(& &1.external_id)
  |> Enum.sort_by(& &1.external_id)
  |> Enum.map(fn course ->
    %{
      external_id: course.external_id,
      name: course.name,
      full_name: course.full_name,
      country: course.country,
      active: course.active
    }
  end)

horses =
  races_with_results
  |> Enum.flat_map(& &1.runners)
  |> Enum.map(& &1.horse)
  |> Enum.uniq_by(& &1.external_id)
  |> Enum.sort_by(& &1.external_id)
  |> Enum.map(fn horse ->
    %{
      external_id: horse.external_id,
      name: horse.name
    }
  end)

races =
  races_with_results
  |> Enum.sort_by(& &1.external_id)
  |> Enum.map(fn race ->
    %{
      external_id: race.external_id,
      course_external_id: race.course.external_id,
      distance_raw: race.distance_raw,
      distance_meters: race.distance_meters,
      age_restriction: race.age_restriction,
      post_time_utc: if(race.post_time, do: Time.to_iso8601(DateTime.to_time(race.post_time)), else: nil),
      status: :scheduled
    }
  end)

runners =
  races_with_results
  |> Enum.flat_map(fn race ->
    Enum.map(race.runners, fn runner ->
      %{
        race_external_id: race.external_id,
        horse_external_id: runner.horse.external_id,
        program_number: runner.program_number,
        weight: runner.weight,
        form: runner.form,
        morning_line: runner.morning_line
      }
    end)
  end)
  |> Enum.sort_by(fn r -> {r.race_external_id, r.program_number} end)

results =
  races_with_results
  |> Enum.sort_by(& &1.external_id)
  |> Enum.map(fn race ->
    %{
      race_external_id: race.external_id,
      race: %{
        finished: race.finished,
        canceled: race.canceled,
        status: race.status
      },
      runners:
        race.runners
        |> Enum.map(fn runner ->
          %{
            program_number: runner.program_number,
            position: runner.position,
            distance_beaten: runner.distance_beaten,
            non_runner: runner.non_runner
          }
        end)
        |> Enum.sort_by(& &1.program_number)
    }
  end)

racing_payload = %{
  courses: courses,
  horses: horses,
  races: races,
  runners: runners
}

results_payload = %{results: results}

File.write!(
  Path.join(target_dir, "curated_racing_data.exs"),
  inspect(racing_payload, pretty: true, limit: :infinity, printable_limit: :infinity) <> "\n"
)

File.write!(
  Path.join(target_dir, "curated_results_data.exs"),
  inspect(results_payload, pretty: true, limit: :infinity, printable_limit: :infinity) <> "\n"
)

IO.puts("Curated seed data exported:")
IO.puts("- races with results: #{length(races_with_results)}")
IO.puts("- courses: #{length(courses)}")
IO.puts("- horses: #{length(horses)}")
IO.puts("- races: #{length(races)}")
IO.puts("- runners: #{length(runners)}")
