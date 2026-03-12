defmodule BetPlaceWeb.Bettor.GameEventListLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Games

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <h1 class="text-3xl font-bold mb-6">Eventos disponibles</h1>
        <div id="events" phx-update="stream" class="space-y-4">
          <div class="hidden only:block text-base-content/50 text-center py-8">
            No hay eventos disponibles en este momento.
          </div>
          <div
            :for={{id, event} <- @streams.events}
            id={id}
            class="card bg-base-100 border border-base-200 shadow"
          >
            <div class="card-body">
              <h2 class="card-title">{event.name}</h2>
              <p class="text-sm text-base-content/60">{event.course.full_name}</p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    events = Games.list_open_game_events()
    {:ok, stream(socket, :events, events)}
  end
end
