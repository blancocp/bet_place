defmodule BetPlace.Api.Client do
  @moduledoc "HTTP client for the horse-racing-usa RapidAPI."

  @base_url "https://horse-racing-usa.p.rapidapi.com"
  @api_host "horse-racing-usa.p.rapidapi.com"

  defp api_key do
    Application.get_env(:bet_place, :racing_api_key)
  end

  defp headers do
    [
      {"x-rapidapi-host", @api_host},
      {"x-rapidapi-key", api_key() || ""},
      {"content-type", "application/json"}
    ]
  end

  @doc "GET /racecards?date=YYYY-MM-DD"
  def fetch_racecards(date) when is_binary(date) do
    get("/racecards", params: [date: date])
  end

  @doc "GET /race/:id_race"
  def fetch_race(id_race) when is_binary(id_race) do
    get("/race/#{id_race}")
  end

  @doc "GET /results?date=YYYY-MM-DD"
  def fetch_results(date) when is_binary(date) do
    get("/results", params: [date: date])
  end

  defp get(path, opts \\ []) do
    params = Keyword.get(opts, :params, [])

    Req.get(@base_url <> path,
      headers: headers(),
      params: params,
      receive_timeout: 15_000
    )
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
