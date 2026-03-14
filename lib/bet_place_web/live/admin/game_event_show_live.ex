defmodule BetPlaceWeb.Admin.GameEventShowLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Games, Betting}
  alias BetPlace.Api.SyncWorker

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Header --%>
        <div class="flex items-start justify-between mb-6">
          <div>
            <.link navigate={~p"/admin/eventos"} class="btn btn-ghost btn-sm gap-1 mb-2">
              <.icon name="hero-arrow-left" class="size-4" /> Eventos
            </.link>
            <h1 class="text-3xl font-bold">{@event.name}</h1>
            <div class="flex items-center gap-3 mt-1">
              <span class={["badge", status_badge_class(@event.status)]}>
                {status_label(@event.status)}
              </span>
              <span class="text-sm text-base-content/60">{@event.course.full_name}</span>
              <span class="text-sm text-base-content/60">{@event.game_type.name}</span>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <%= if @event.status in [:open, :closed] do %>
              <button
                phx-click="sync_event"
                class={["btn btn-sm btn-outline gap-1", if(@syncing, do: "btn-disabled")]}
                disabled={@syncing}
              >
                <.icon name="hero-arrow-path" class={["size-4", if(@syncing, do: "animate-spin")]} />
                {if @syncing, do: "Sincronizando...", else: "Sync carreras"}
              </button>
            <% end %>
            <%= if @event.status == :open do %>
              <button
                phx-click="close_event"
                class="btn btn-warning btn-sm"
                data-confirm="¿Cerrar apuestas para este evento?"
              >
                Cerrar apuestas
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Info cards --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
          <div class="stat bg-base-100 border border-base-200 rounded-box p-3">
            <div class="stat-title text-xs">Pool total</div>
            <div class="stat-value text-lg">${@event.total_pool}</div>
          </div>
          <div class="stat bg-base-100 border border-base-200 rounded-box p-3">
            <div class="stat-title text-xs">Premio</div>
            <div class="stat-value text-lg">${@event.prize_pool}</div>
          </div>
          <div class="stat bg-base-100 border border-base-200 rounded-box p-3">
            <div class="stat-title text-xs">Casa</div>
            <div class="stat-value text-lg">${@event.house_amount}</div>
          </div>
          <div class="stat bg-base-100 border border-base-200 rounded-box p-3">
            <div class="stat-title text-xs">Cierra</div>
            <div class="stat-value text-sm">
              {if @event.betting_closes_at,
                do: Calendar.strftime(@event.betting_closes_at, "%d/%m %H:%M"),
                else: "—"}
            </div>
          </div>
        </div>

        <%!-- Races table --%>
        <div class="card bg-base-100 border border-base-200 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg mb-3">Carreras del evento</h2>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Carrera</th>
                    <th>Hora</th>
                    <th>Distancia</th>
                    <th>Estado</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={er <- @event_races} class="hover">
                    <td class="font-mono font-bold">{er.race_order}</td>
                    <td class="font-mono text-xs">{er.race.external_id}</td>
                    <td class="text-sm">
                      {if er.race.post_time,
                        do: Calendar.strftime(er.race.post_time, "%d/%m %H:%M"),
                        else: "—"}
                    </td>
                    <td class="text-sm">{er.race.distance_raw || "—"}</td>
                    <td>
                      <span class={["badge badge-xs", er_status_class(er.status)]}>
                        {er.status}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- HvH Matchups section --%>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <div class="flex items-center justify-between mb-3">
              <h2 class="card-title text-lg">Matchups Horse vs Horse</h2>
              <%= if @event.status in [:open, :closed] do %>
                <.link
                  navigate={~p"/admin/eventos/#{@event.id}/matchups/nuevo"}
                  class="btn btn-outline btn-sm gap-1"
                >
                  <.icon name="hero-plus" class="size-4" /> Crear matchup
                </.link>
              <% end %>
            </div>

            <%= if @matchups == [] do %>
              <p class="text-base-content/50 text-sm text-center py-4">
                No hay matchups creados para este evento.
              </p>
            <% else %>
              <div class="space-y-3">
                <div
                  :for={matchup <- @matchups}
                  class="flex items-center justify-between p-3 bg-base-200 rounded-lg"
                >
                  <div class="flex items-center gap-4">
                    <div class="text-sm">
                      <span class="font-medium">Lado A:</span>
                      <span class="text-base-content/70 ml-1">
                        {matchup.hvh_matchup_sides
                        |> Enum.filter(&(&1.side == :a))
                        |> Enum.map_join(", ", & &1.runner.horse.name)}
                      </span>
                    </div>
                    <span class="text-base-content/40">vs</span>
                    <div class="text-sm">
                      <span class="font-medium">Lado B:</span>
                      <span class="text-base-content/70 ml-1">
                        {matchup.hvh_matchup_sides
                        |> Enum.filter(&(&1.side == :b))
                        |> Enum.map_join(", ", & &1.runner.horse.name)}
                      </span>
                    </div>
                  </div>
                  <span class={["badge badge-sm", matchup_status_class(matchup.status)]}>
                    {matchup.status}
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    event = Games.get_game_event!(id)
    event_races = Games.list_game_event_races(id)
    matchups = Betting.list_hvh_matchups_for_event(id)

    {:ok,
     assign(socket,
       event: event,
       event_races: event_races,
       matchups: matchups,
       syncing: false
     )}
  end

  def handle_event("sync_event", _params, socket) do
    SyncWorker.sync_event(socket.assigns.event.id)

    race_count = length(socket.assigns.event_races)
    estimated = race_count * 7

    {:noreply,
     socket
     |> assign(:syncing, true)
     |> put_flash(
       :info,
       "Sincronizando #{race_count} carreras del evento (~#{estimated}s). " <>
         "Recarga la página cuando termine."
     )}
  end

  def handle_event("close_event", _params, socket) do
    case Games.update_game_event_status(socket.assigns.event, :closed) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Apuestas cerradas.")
         |> assign(event: event)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo cerrar el evento.")}
    end
  end

  defp status_badge_class(:open), do: "badge-success"
  defp status_badge_class(:closed), do: "badge-warning"
  defp status_badge_class(:finished), do: "badge-info"
  defp status_badge_class(:canceled), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  defp status_label(:draft), do: "Borrador"
  defp status_label(:open), do: "Abierto"
  defp status_label(:closed), do: "Cerrado"
  defp status_label(:processing), do: "Procesando"
  defp status_label(:finished), do: "Finalizado"
  defp status_label(:canceled), do: "Cancelado"
  defp status_label(other), do: to_string(other)

  defp er_status_class(:finished), do: "badge-success"
  defp er_status_class(:canceled), do: "badge-error"
  defp er_status_class(:running), do: "badge-warning"
  defp er_status_class(_), do: "badge-ghost"

  defp matchup_status_class(:open), do: "badge-success"
  defp matchup_status_class(:finished), do: "badge-info"
  defp matchup_status_class(:void), do: "badge-error"
  defp matchup_status_class(_), do: "badge-ghost"
end
