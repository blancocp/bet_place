defmodule BetPlaceWeb.Bettor.GameEventListLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Games

  @tick_interval 60_000

  def mount(_params, _session, socket) do
    events = Games.list_open_game_events()

    if connected?(socket), do: Process.send_after(self(), :refresh, @tick_interval)

    {:ok, stream(socket, :events, events)}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @tick_interval)
    events = Games.list_open_game_events()
    {:noreply, stream(socket, :events, events, reset: true)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <h1 class="text-2xl font-bold mb-6">Eventos disponibles</h1>

        <div id="events" phx-update="stream" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div class="hidden only:block col-span-full text-base-content/50 text-center py-16">
            No hay eventos disponibles en este momento.
          </div>

          <div
            :for={{id, event} <- @streams.events}
            id={id}
            class="card bg-base-100 border border-base-200 shadow hover:shadow-md transition-shadow"
          >
            <div class="card-body p-4">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <h2 class="font-bold leading-tight">{event.name}</h2>
                  <p class="text-sm text-base-content/60 mt-0.5">{event.course.full_name}</p>
                </div>
                <span class={event_status_badge(event.status)}>
                  {status_label(event.status)}
                </span>
              </div>

              <div class="mt-3 flex items-center justify-between text-sm">
                <span class="text-base-content/60">
                  {event.game_type.name}
                </span>
                <span class="font-mono text-warning text-xs">
                  {format_closes_at(event.betting_closes_at)}
                </span>
              </div>

              <div class="card-actions mt-3">
                <.link
                  navigate={~p"/eventos/#{event.id}"}
                  class="btn btn-primary btn-sm w-full"
                >
                  Ver y apostar
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp event_status_badge(:open), do: "badge badge-success badge-sm"
  defp event_status_badge(:closed), do: "badge badge-warning badge-sm"
  defp event_status_badge(_), do: "badge badge-ghost badge-sm"

  defp status_label(:open), do: "Abierto"
  defp status_label(:closed), do: "Cerrado"
  defp status_label(_), do: "Activo"

  defp format_closes_at(nil), do: ""

  defp format_closes_at(closes_at) do
    diff = DateTime.diff(closes_at, DateTime.utc_now(), :second)

    cond do
      diff <= 0 -> "Cerrado"
      diff < 3600 -> "Cierra en #{div(diff, 60)}min"
      true -> "Cierra en #{div(diff, 3600)}h"
    end
  end
end
