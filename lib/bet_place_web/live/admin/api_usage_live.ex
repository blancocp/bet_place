defmodule BetPlaceWeb.Admin.ApiUsageLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Api.ApiSyncLog

  def mount(_params, _session, socket) do
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(:year, today.year)
     |> assign(:month, today.month)
     |> load_data()}
  end

  def handle_event("prev_month", _params, socket) do
    %{year: y, month: m} = socket.assigns

    {new_y, new_m} =
      if m == 1, do: {y - 1, 12}, else: {y, m - 1}

    {:noreply,
     socket
     |> assign(:year, new_y)
     |> assign(:month, new_m)
     |> load_data()}
  end

  def handle_event("next_month", _params, socket) do
    %{year: y, month: m} = socket.assigns

    {new_y, new_m} =
      if m == 12, do: {y + 1, 1}, else: {y, m + 1}

    {:noreply,
     socket
     |> assign(:year, new_y)
     |> assign(:month, new_m)
     |> load_data()}
  end

  defp load_data(socket) do
    %{year: y, month: m} = socket.assigns
    month_totals = ApiSyncLog.requests_for_month(y, m)
    daily = ApiSyncLog.daily_history_for_month(y, m)

    socket
    |> assign(:month_totals, month_totals)
    |> assign(:daily, daily)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="flex items-center justify-between mb-6">
          <div>
            <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm gap-1 mb-2">
              <.icon name="hero-arrow-left" class="size-4" /> Dashboard
            </.link>
            <h1 class="text-3xl font-bold">Uso de API</h1>
          </div>
        </div>

        <%!-- Month navigation --%>
        <div class="flex items-center justify-between mb-6">
          <button phx-click="prev_month" class="btn btn-ghost btn-sm gap-1">
            <.icon name="hero-chevron-left" class="size-4" /> Anterior
          </button>
          <h2 class="text-xl font-bold">{month_name(@month)} {@year}</h2>
          <button phx-click="next_month" class="btn btn-ghost btn-sm gap-1">
            Siguiente <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>

        <%!-- Month summary cards --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold font-mono text-primary">{@month_totals.total}</div>
              <div class="text-sm text-base-content/60">Total requests</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold font-mono text-success">{@month_totals.ok}</div>
              <div class="text-sm text-base-content/60">Exitosos</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold font-mono text-error">{@month_totals.error}</div>
              <div class="text-sm text-base-content/60">Errores</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold font-mono">
                {if @month_totals.total > 0,
                  do: "#{Float.round(@month_totals.ok / @month_totals.total * 100, 1)}%",
                  else: "—"}
              </div>
              <div class="text-sm text-base-content/60">Tasa de éxito</div>
            </div>
          </div>
        </div>

        <%!-- Daily breakdown table --%>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg mb-3">Detalle diario</h2>

            <div :if={@daily == []} class="text-sm text-base-content/40 text-center py-8">
              Sin requests registrados en este mes.
            </div>

            <div :if={@daily != []} class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Fecha</th>
                    <th class="text-right">Total</th>
                    <th class="text-right">OK</th>
                    <th class="text-right">Errores</th>
                    <th class="text-right">Racecards</th>
                    <th class="text-right">Results</th>
                    <th class="text-right">Race detail</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={day <- @daily} class="hover">
                    <td class="font-mono text-sm">{Calendar.strftime(day.date, "%d/%m/%Y")}</td>
                    <td class="text-right font-mono font-bold">{day.total}</td>
                    <td class="text-right font-mono text-success">{day.ok}</td>
                    <td class={[
                      "text-right font-mono",
                      if(day.error > 0, do: "text-error", else: "text-base-content/30")
                    ]}>
                      {day.error}
                    </td>
                    <td class="text-right font-mono text-base-content/70">
                      {Map.get(day.by_endpoint, :racecards, 0)}
                    </td>
                    <td class="text-right font-mono text-base-content/70">
                      {Map.get(day.by_endpoint, :results, 0)}
                    </td>
                    <td class="text-right font-mono text-base-content/70">
                      {Map.get(day.by_endpoint, :race, 0)}
                    </td>
                  </tr>
                </tbody>
                <tfoot>
                  <tr class="font-bold">
                    <td>Total</td>
                    <td class="text-right font-mono">{@month_totals.total}</td>
                    <td class="text-right font-mono text-success">{@month_totals.ok}</td>
                    <td class="text-right font-mono text-error">{@month_totals.error}</td>
                    <td colspan="3"></td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp month_name(1), do: "Enero"
  defp month_name(2), do: "Febrero"
  defp month_name(3), do: "Marzo"
  defp month_name(4), do: "Abril"
  defp month_name(5), do: "Mayo"
  defp month_name(6), do: "Junio"
  defp month_name(7), do: "Julio"
  defp month_name(8), do: "Agosto"
  defp month_name(9), do: "Septiembre"
  defp month_name(10), do: "Octubre"
  defp month_name(11), do: "Noviembre"
  defp month_name(12), do: "Diciembre"
end
