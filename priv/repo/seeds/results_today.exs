alias BetPlace.Api.SeedResultSimulator

case SeedResultSimulator.run_today() do
  {:ok, summary} ->
    IO.puts(
      "Seed results today complete: total=#{summary.total}, applied=#{summary.applied}, skipped=#{summary.skipped}"
    )

  {:error, reason} ->
    raise "Error applying today results seed: #{inspect(reason)}"
end
