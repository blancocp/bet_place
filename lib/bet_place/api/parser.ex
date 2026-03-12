defmodule BetPlace.Api.Parser do
  @moduledoc "Parses responses from the horse-racing API into maps ready for Ecto upserts."

  # ── Racecards ─────────────────────────────────────────────────────────────

  @doc """
  Parses the /racecards response.
  Returns a list of race maps with course attrs embedded.
  """
  def parse_racecards(items) when is_list(items) do
    Enum.map(items, &parse_racecard_item/1)
  end

  defp parse_racecard_item(item) do
    course_raw = item["course"]
    {name, country} = split_course(course_raw)

    %{
      course: %{
        external_id: course_raw,
        name: name,
        full_name: course_raw,
        country: country
      },
      race: %{
        external_id: item["id_race"],
        race_date: parse_date(item["date"]),
        post_time: parse_datetime(item["date"]),
        distance_raw: item["distance"],
        distance_meters: parse_distance(item["distance"]),
        age_restriction: item["age"],
        finished: item["finished"] == "1",
        canceled: item["canceled"] == "1",
        status: infer_race_status(item)
      }
    }
  end

  # ── Race Detail ───────────────────────────────────────────────────────────

  @doc """
  Parses the /race/:id response.
  Returns a map with race attrs and a list of runner maps.
  """
  def parse_race_detail(data) when is_map(data) do
    course_raw = data["course"]
    {name, country} = split_course(course_raw)

    runners =
      (data["horses"] || [])
      |> Enum.map(&parse_runner/1)

    %{
      course: %{
        external_id: course_raw,
        name: name,
        full_name: course_raw,
        country: country
      },
      race: %{
        external_id: data["id_race"],
        race_date: parse_date(data["date"]),
        post_time: parse_datetime(data["date"]),
        distance_raw: data["distance"],
        distance_meters: parse_distance(data["distance"]),
        age_restriction: data["age"],
        finished: data["finished"] == "1",
        canceled: data["canceled"] == "1",
        status: infer_race_status(data)
      },
      runners: runners
    }
  end

  defp parse_runner(horse) do
    %{
      horse: %{
        external_id: horse["id_horse"],
        name: horse["horse"]
      },
      jockey_name: horse["jockey"],
      trainer_name: horse["trainer"],
      runner: %{
        program_number: parse_integer(horse["number"]),
        weight: horse["weight"],
        form: horse["form"],
        morning_line: parse_decimal(horse["sp"]),
        non_runner: horse["non_runner"] == "1",
        position: parse_position(horse["position"]),
        distance_beaten: presence(horse["distance_beaten"])
      }
    }
  end

  # ── Results ───────────────────────────────────────────────────────────────

  @doc "Results response has the same shape as racecards."
  def parse_results(items) when is_list(items), do: parse_racecards(items)

  # ── Distance conversion ───────────────────────────────────────────────────

  @furlong_meters 201.168

  @distance_table %{
    "5 furlongs" => 1006,
    "5 1/2 furlongs" => 1107,
    "6 furlongs" => 1207,
    "6 1/2 furlongs" => 1308,
    "7 furlongs" => 1408,
    "7 1/2 furlongs" => 1509,
    "1 mile" => 1609,
    "1 mile 70 yards" => 1673,
    "1 1/16 miles" => 1710,
    "1 1/8 miles" => 1810,
    "1 3/16 miles" => 1911,
    "1 1/4 miles" => 2012,
    "1 3/8 miles" => 2414,
    "1 1/2 miles" => 2414,
    "1 3/4 miles" => 2816
  }

  @doc "Converts a raw distance string to meters. Returns nil if unrecognized."
  def parse_distance(nil), do: nil
  def parse_distance(""), do: nil

  def parse_distance(raw) when is_binary(raw) do
    normalized = String.trim(String.downcase(raw))

    case Map.get(@distance_table, normalized) do
      nil -> calculate_distance(normalized)
      meters -> meters
    end
  end

  defp calculate_distance(raw) do
    cond do
      # "N furlongs"
      Regex.match?(~r/^(\d+(?:\.\d+)?) furlongs?$/, raw) ->
        [_, n] = Regex.run(~r/^(\d+(?:\.\d+)?) furlongs?$/, raw)
        round(String.to_float(n) * @furlong_meters)

      # "N 1/2 furlongs"
      Regex.match?(~r/^(\d+) 1\/2 furlongs?$/, raw) ->
        [_, n] = Regex.run(~r/^(\d+) 1\/2 furlongs?$/, raw)
        round((String.to_integer(n) + 0.5) * @furlong_meters)

      true ->
        nil
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp split_course(raw) when is_binary(raw) do
    case Regex.run(~r/^(.+?) \(([A-Z]+)\)$/, raw) do
      [_, name, country] -> {name, country}
      _ -> {raw, "USA"}
    end
  end

  defp infer_race_status(%{"canceled" => "1"}), do: :canceled
  defp infer_race_status(%{"finished" => "1"}), do: :finished
  defp infer_race_status(_), do: :scheduled

  defp parse_date(nil), do: nil

  defp parse_date(datetime_str) when is_binary(datetime_str) do
    case String.split(datetime_str, " ") do
      [date_part | _] ->
        case Date.from_iso8601(date_part) do
          {:ok, date} -> date
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_str) when is_binary(datetime_str) do
    normalized = String.replace(datetime_str, " ", "T") <> "Z"

    case DateTime.from_iso8601(normalized) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil

  defp parse_decimal(str) when is_binary(str) do
    case Decimal.parse(str) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp parse_position(nil), do: nil
  defp parse_position(""), do: nil

  defp parse_position(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(str), do: str
end
