defmodule BetPlaceWeb.Admin.HvhMatchupNewLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Games, Betting, Racing}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/admin/eventos/#{@event.id}"} class="btn btn-ghost btn-sm gap-1 mb-4">
            <.icon name="hero-arrow-left" class="size-4" /> Volver al evento
          </.link>
          <h1 class="text-3xl font-bold">Nuevo matchup HvH</h1>
          <p class="text-base-content/60 mt-1">{@event.name}</p>
        </div>

        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <div class="form-control mb-4">
              <label class="label"><span class="label-text font-medium">Carrera</span></label>
              <select
                phx-change="select_race"
                name="race_id"
                class="select select-bordered"
              >
                <option value="">Seleccionar carrera...</option>
                <option
                  :for={er <- @event_races}
                  value={er.race_id}
                  selected={@selected_race_id == er.race_id}
                >
                  Carrera #{er.race_order} — {er.race.external_id}
                  {if er.race.post_time,
                    do: " (#{Calendar.strftime(er.race.post_time, "%H:%M")})",
                    else: ""}
                </option>
              </select>
            </div>

            <%= if @runners != [] do %>
              <form phx-submit="create" id="matchup-form">
                <input type="hidden" name="race_id" value={@selected_race_id} />

                <div class="grid grid-cols-2 gap-6">
                  <div>
                    <h3 class="font-semibold mb-3 text-center">🔵 Lado A</h3>
                    <div class="space-y-2">
                      <label
                        :for={runner <- @runners}
                        class="flex items-center gap-3 p-2 rounded-lg hover:bg-base-200 cursor-pointer"
                      >
                        <input
                          type="checkbox"
                          name="side_a[]"
                          value={runner.id}
                          class="checkbox checkbox-sm checkbox-primary"
                        />
                        <div>
                          <div class="font-medium text-sm">{runner.horse.name}</div>
                          <div class="text-xs text-base-content/60">#{runner.program_number}</div>
                        </div>
                      </label>
                    </div>
                  </div>
                  <div>
                    <h3 class="font-semibold mb-3 text-center">🔴 Lado B</h3>
                    <div class="space-y-2">
                      <label
                        :for={runner <- @runners}
                        class="flex items-center gap-3 p-2 rounded-lg hover:bg-base-200 cursor-pointer"
                      >
                        <input
                          type="checkbox"
                          name="side_b[]"
                          value={runner.id}
                          class="checkbox checkbox-sm checkbox-error"
                        />
                        <div>
                          <div class="font-medium text-sm">{runner.horse.name}</div>
                          <div class="text-xs text-base-content/60">#{runner.program_number}</div>
                        </div>
                      </label>
                    </div>
                  </div>
                </div>

                <div class="card-actions justify-end mt-6">
                  <.link navigate={~p"/admin/eventos/#{@event.id}"} class="btn btn-ghost">
                    Cancelar
                  </.link>
                  <button type="submit" class="btn btn-primary" phx-disable-with="Creando...">
                    Crear matchup
                  </button>
                </div>
              </form>
            <% end %>

            <%= if @selected_race_id && @runners == [] do %>
              <div class="alert alert-warning">
                <.icon name="hero-exclamation-triangle" class="size-5" />
                <span>No hay participantes para esta carrera. Sincroniza los detalles primero.</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"event_id" => event_id}, _session, socket) do
    event = Games.get_game_event!(event_id)
    event_races = Games.list_game_event_races(event_id)

    {:ok,
     assign(socket,
       event: event,
       event_races: event_races,
       selected_race_id: nil,
       runners: []
     )}
  end

  def handle_event("select_race", %{"race_id" => ""}, socket) do
    {:noreply, assign(socket, selected_race_id: nil, runners: [])}
  end

  def handle_event("select_race", %{"race_id" => race_id}, socket) do
    runners = Racing.list_runners_for_race(race_id)
    {:noreply, assign(socket, selected_race_id: race_id, runners: runners)}
  end

  def handle_event("create", params, socket) do
    race_id = params["race_id"]
    side_a = List.wrap(params["side_a"] || [])
    side_b = List.wrap(params["side_b"] || [])

    cond do
      side_a == [] or side_b == [] ->
        {:noreply,
         put_flash(socket, :error, "Debes seleccionar al menos un caballo en cada lado.")}

      Enum.any?(side_a, &(&1 in side_b)) ->
        {:noreply, put_flash(socket, :error, "Un caballo no puede estar en ambos lados.")}

      true ->
        matchup_attrs = %{
          game_event_id: socket.assigns.event.id,
          race_id: race_id,
          created_by: socket.assigns.current_scope.user.id,
          status: :open
        }

        case Betting.create_hvh_matchup_with_sides(matchup_attrs, side_a, side_b) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Matchup creado correctamente.")
             |> push_navigate(to: ~p"/admin/eventos/#{socket.assigns.event.id}")}

          {:error, _, _, _} ->
            {:noreply, put_flash(socket, :error, "Error al crear el matchup.")}
        end
    end
  end
end
