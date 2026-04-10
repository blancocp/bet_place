defmodule BetPlaceWeb.Admin.HvhMatchupNewLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Games, Betting, Racing}

  # Sync race selection with the URL (?race_id=) so reload/reconnect keep state and
  # LiveView always applies the same logic (avoids duplicate name="race_id" issues).

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/admin/eventos/#{@event.id}"} class="btn btn-ghost btn-sm gap-1 mb-4">
            <.icon name="hero-arrow-left" class="size-4" /> Volver al evento
          </.link>
          <h1 class="text-3xl font-bold">Nuevo VS — Bloques Macho y Hembra</h1>
          <p class="text-base-content/60 mt-1">{@event.name}</p>
        </div>

        <div class="alert alert-info mb-6 shadow-sm">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div class="text-sm">
            <p class="font-semibold mb-1">Cómo conformar los grupos</p>
            <ol class="list-decimal list-inside space-y-1 text-base-content/90">
              <li>
                Elige la <strong>carrera</strong> del evento donde aplica este enfrentamiento.
              </li>
              <li>
                Reparte cada <strong>ejemplar</strong>
                entre <strong>Macho</strong>
                (favorito / bloque A)
                y <strong>Hembra</strong>
                (outsiders / bloque B) usando las casillas.
                Debe haber la <strong>misma cantidad</strong>
                en cada bloque (mínimo uno por lado).
                Un mismo caballo no puede estar en los dos.
              </li>
              <li>
                Define el <strong>porcentaje de pago</strong> y guarda el matchup.
              </li>
            </ol>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-base border-b border-base-300 pb-2 mb-4">
              <span class="badge badge-primary badge-lg font-mono">1</span> Carrera del enfrentamiento
            </h2>
            <div class="form-control mb-2">
              <label class="label pt-0">
                <span class="label-text font-medium">Carrera</span>
              </label>
              <p class="text-xs text-base-content/60 mb-2">
                Solo verás los participantes de la carrera elegida para asignarlos a cada bloque.
              </p>
              <form id="hvh-race-picker" phx-change="select_race" class="max-w-xl">
                <label class="sr-only" for="hvh-race-select">Carrera del enfrentamiento</label>
                <select
                  id="hvh-race-select"
                  name="pick_race_id"
                  class="select select-bordered w-full"
                >
                  <option value="">Seleccionar carrera…</option>
                  <option
                    :for={er <- @event_races}
                    value={to_string(er.race_id)}
                    selected={race_option_selected?(@selected_race_id, er.race_id)}
                  >
                    {er.race_order}ª válida — ID {er.race.external_id}
                    {if er.race.post_time,
                      do: " · #{Calendar.strftime(er.race.post_time, "%d/%m %H:%M")}",
                      else: ""}
                  </option>
                </select>
              </form>
              <p class="text-xs text-base-content/50 mt-3">
                Si el desplegable no responde, elige la carrera con los accesos rápidos:
              </p>
              <div class="mt-2 flex flex-wrap gap-2">
                <button
                  :for={er <- @event_races}
                  type="button"
                  class="btn btn-xs btn-outline gap-1"
                  phx-click="pick_race"
                  phx-value-race_id={to_string(er.race_id)}
                >
                  <.icon name="hero-chevron-right" class="size-3" /> {er.race_order}ª válida
                </button>
              </div>
            </div>

            <h2 class="card-title text-base border-b border-base-300 pb-2 mb-4 mt-8">
              <span class="badge badge-secondary badge-lg font-mono">2</span> Grupos Macho y Hembra
            </h2>

            <%= if @selected_race_id == nil do %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="rounded-xl border-2 border-dashed border-base-300 bg-base-200/30 p-6 text-center">
                  <.icon name="hero-rectangle-stack" class="size-10 mx-auto mb-2 text-primary/50" />
                  <p class="font-semibold text-primary">Bloque Macho</p>
                  <p class="text-xs text-base-content/60 mt-2">
                    Aquí marcarás los ejemplares del grupo Macho cuando elijas una carrera.
                  </p>
                </div>
                <div class="rounded-xl border-2 border-dashed border-base-300 bg-base-200/30 p-6 text-center">
                  <.icon name="hero-rectangle-stack" class="size-10 mx-auto mb-2 text-secondary/50" />
                  <p class="font-semibold text-secondary">Bloque Hembra</p>
                  <p class="text-xs text-base-content/60 mt-2">
                    Aquí marcarás los del grupo Hembra. Son etiquetas de mercado (no sexo biológico).
                  </p>
                </div>
              </div>
            <% end %>

            <%= if @selected_race_id && @runners == [] do %>
              <div class="alert alert-warning">
                <.icon name="hero-exclamation-triangle" class="size-5" />
                <span>
                  No hay participantes cargados para esta carrera. Sincroniza el detalle de la carrera (racecard) y vuelve a intentar.
                </span>
              </div>
            <% end %>

            <%= if @runners != [] do %>
              <form phx-submit="create" id="matchup-form">
                <input type="hidden" name="race_id" value={@selected_race_id} />
                <div class="mb-6 max-w-xl">
                  <label class="label">
                    <span class="label-text font-medium">Porcentaje de pago (%)</span>
                  </label>
                  <p class="text-xs text-base-content/60 mb-2">
                    Sobre el monto apostado si gana el bloque elegido (p. ej. 80 → el ganador cobra monto × 1,80 en total).
                  </p>
                  <input
                    type="number"
                    name="payout_pct"
                    min="1"
                    step="0.01"
                    value="80"
                    class="input input-bordered w-full"
                  />
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div class="rounded-xl border border-primary/30 bg-primary/5 p-4">
                    <h3 class="font-bold mb-1 text-center text-primary flex items-center justify-center gap-2">
                      <.icon name="hero-flag" class="size-5" /> Bloque Macho
                    </h3>
                    <p class="text-xs text-center text-base-content/60 mb-4">
                      Marca el mismo número de ejemplares que en Hembra.
                    </p>
                    <div class="space-y-2 max-h-80 overflow-y-auto pr-1">
                      <%= for runner <- @runners do %>
                        <label
                          for={"hvh-side-a-#{runner.id}"}
                          class="flex items-center gap-3 p-2 rounded-lg hover:bg-base-100 cursor-pointer border border-transparent hover:border-primary/20"
                        >
                          <input
                            type="checkbox"
                            id={"hvh-side-a-#{runner.id}"}
                            name="side_a[]"
                            value={runner.id}
                            class="checkbox checkbox-sm checkbox-primary"
                          />
                          <div class="min-w-0">
                            <div class="font-medium text-sm truncate">{runner.horse.name}</div>
                            <div class="text-xs text-base-content/60">
                              Programa #{runner.program_number}
                            </div>
                          </div>
                        </label>
                      <% end %>
                    </div>
                  </div>
                  <div class="rounded-xl border border-secondary/30 bg-secondary/5 p-4">
                    <h3 class="font-bold mb-1 text-center text-secondary flex items-center justify-center gap-2">
                      <.icon name="hero-flag" class="size-5" /> Bloque Hembra
                    </h3>
                    <p class="text-xs text-center text-base-content/60 mb-4">
                      Marca el mismo número de ejemplares que en Macho.
                    </p>
                    <div class="space-y-2 max-h-80 overflow-y-auto pr-1">
                      <%= for runner <- @runners do %>
                        <label
                          for={"hvh-side-b-#{runner.id}"}
                          class="flex items-center gap-3 p-2 rounded-lg hover:bg-base-100 cursor-pointer border border-transparent hover:border-secondary/20"
                        >
                          <input
                            type="checkbox"
                            id={"hvh-side-b-#{runner.id}"}
                            name="side_b[]"
                            value={runner.id}
                            class="checkbox checkbox-sm checkbox-secondary"
                          />
                          <div class="min-w-0">
                            <div class="font-medium text-sm truncate">{runner.horse.name}</div>
                            <div class="text-xs text-base-content/60">
                              Programa #{runner.program_number}
                            </div>
                          </div>
                        </label>
                      <% end %>
                    </div>
                  </div>
                </div>

                <div class="card-actions justify-end mt-8 flex-wrap gap-2">
                  <.link navigate={~p"/admin/eventos/#{@event.id}"} class="btn btn-ghost">
                    Cancelar
                  </.link>
                  <button type="submit" class="btn btn-primary" phx-disable-with="Creando…">
                    <.icon name="hero-check" class="size-4" /> Crear matchup
                  </button>
                </div>
              </form>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"event_id" => event_id} = params, _session, socket) do
    event = Games.get_game_event!(event_id)
    event_races = Games.list_game_event_races(event_id)

    socket =
      socket
      |> assign(:event, event)
      |> assign(:event_races, event_races)
      |> apply_race_from_params(params["race_id"])

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_race_from_params(socket, params["race_id"])}
  end

  def handle_event("select_race", params, socket) do
    race_id = params["pick_race_id"] || params["race_id"] || ""
    {:noreply, patch_to_race(socket, race_id)}
  end

  def handle_event("pick_race", %{"race_id" => race_id}, socket) do
    {:noreply, patch_to_race(socket, race_id)}
  end

  def handle_event("create", params, socket) do
    race_id = params["race_id"]
    side_a = List.wrap(params["side_a"] || [])
    side_b = List.wrap(params["side_b"] || [])

    cond do
      side_a == [] or side_b == [] ->
        {:noreply,
         put_flash(socket, :error, "Debes seleccionar al menos un ejemplar en cada bloque.")}

      length(side_a) != length(side_b) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Debe haber la misma cantidad de ejemplares en Macho y en Hembra."
         )}

      Enum.any?(side_a, &(&1 in side_b)) ->
        {:noreply, put_flash(socket, :error, "Un caballo no puede estar en ambos lados.")}

      true ->
        payout_pct = parse_decimal(params["payout_pct"], Decimal.new("80.00"))

        matchup_attrs = %{
          game_event_id: socket.assigns.event.id,
          race_id: race_id,
          created_by: socket.assigns.current_scope.user.id,
          status: :open,
          payout_pct: payout_pct
        }

        case Betting.create_hvh_matchup_with_sides(matchup_attrs, side_a, side_b) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Matchup creado correctamente.")
             |> push_navigate(to: ~p"/admin/eventos/#{socket.assigns.event.id}")}

          {:error, :unequal_side_counts} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Debe haber la misma cantidad de ejemplares en Macho y en Hembra."
             )}

          {:error, :empty_side} ->
            {:noreply,
             put_flash(socket, :error, "Debes seleccionar al menos un ejemplar en cada bloque.")}

          {:error, _, _, _} ->
            {:noreply, put_flash(socket, :error, "Error al crear el matchup.")}
        end
    end
  end

  defp patch_to_race(socket, race_id) when race_id in [nil, ""] do
    push_patch(socket, to: matchup_new_path(socket.assigns.event.id))
  end

  defp patch_to_race(socket, race_id) do
    push_patch(socket,
      to: matchup_new_path(socket.assigns.event.id, %{"race_id" => race_id})
    )
  end

  defp matchup_new_path(event_id, query \\ %{}) do
    base = ~p"/admin/eventos/#{event_id}/matchups/nuevo"

    case query do
      %{} = m when map_size(m) == 0 -> base
      other -> base <> "?" <> URI.encode_query(other)
    end
  end

  defp apply_race_from_params(socket, race_id) when race_id in [nil, ""] do
    assign(socket, selected_race_id: nil, runners: [])
  end

  defp apply_race_from_params(socket, race_id) do
    assign(socket,
      selected_race_id: race_id,
      runners: Racing.list_runners_for_race(race_id)
    )
  end

  defp race_option_selected?(selected, er_race_id) do
    selected && to_string(selected) == to_string(er_race_id)
  end

  defp parse_decimal(nil, default), do: default

  defp parse_decimal(value, default) do
    case Decimal.parse(to_string(value)) do
      {decimal, ""} -> decimal
      _ -> default
    end
  end
end
