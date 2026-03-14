defmodule BetPlaceWeb.Admin.GameEventNewLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Games, Racing}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/admin/eventos"} class="btn btn-ghost btn-sm gap-1 mb-4">
            <.icon name="hero-arrow-left" class="size-4" /> Volver
          </.link>
          <h1 class="text-3xl font-bold">Crear evento de apuestas</h1>
        </div>

        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <.form for={@form} id="event-form" phx-change="select_options" phx-submit="create">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Tipo de juego</span>
                  </label>
                  <select name="game_type_id" class="select select-bordered" required>
                    <option value="">Seleccionar...</option>
                    <option
                      :for={gt <- @game_types}
                      value={gt.id}
                      selected={@selected_game_type_id == gt.id}
                    >
                      {gt.name}
                    </option>
                  </select>
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text font-medium">Hipódromo</span></label>
                  <select name="course_id" class="select select-bordered" required>
                    <option value="">Seleccionar...</option>
                    <option
                      :for={c <- @courses}
                      value={c.id}
                      selected={@selected_course_id == c.id}
                    >
                      {c.full_name}
                    </option>
                  </select>
                </div>
              </div>

              <div class="form-control mt-4">
                <.input
                  field={@form[:name]}
                  label="Nombre del evento"
                  placeholder="Ej: Polla Aqueduct - 12 Mar"
                  required
                />
              </div>

              <%!-- Preview de carreras --%>
              <%= if @preview_races != [] do %>
                <div class="mt-6">
                  <h3 class="font-semibold mb-3">
                    Carreras incluidas ({length(@preview_races)})
                  </h3>
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th>#</th>
                          <th>ID externo</th>
                          <th>Fecha</th>
                          <th>Distancia</th>
                          <th>Estado</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={{race, i} <- Enum.with_index(@preview_races, 1)}>
                          <td class="font-mono">{i}</td>
                          <td class="font-mono text-xs">{race.external_id}</td>
                          <td class="text-sm">
                            {if race.post_time,
                              do: Calendar.strftime(race.post_time, "%d/%m %H:%M"),
                              else: "—"}
                          </td>
                          <td class="text-sm">{race.distance_raw || "—"}</td>
                          <td>
                            <span class="badge badge-xs badge-outline">{race.status}</span>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              <% end %>

              <%= if @selected_course_id && @preview_races == [] do %>
                <div class="alert alert-warning mt-4">
                  <.icon name="hero-exclamation-triangle" class="size-5" />
                  <span>
                    No hay carreras programadas para hoy en este hipódromo. Ejecuta una sincronización de racecards primero.
                  </span>
                </div>
              <% end %>

              <div class="card-actions justify-end mt-6">
                <.link navigate={~p"/admin/eventos"} class="btn btn-ghost">
                  Cancelar
                </.link>
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={@preview_races == []}
                  phx-disable-with="Creando..."
                >
                  Crear evento ({length(@preview_races)} carreras)
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(%{"name" => "", "game_type_id" => "", "course_id" => ""})

    {:ok,
     assign(socket,
       form: form,
       game_types: Games.list_game_types(),
       courses: Racing.list_courses(),
       selected_game_type_id: nil,
       selected_course_id: nil,
       preview_races: []
     )}
  end

  def handle_event("select_options", params, socket) do
    course_id = presence(params["course_id"])
    game_type_id = presence(params["game_type_id"])
    current_name = params["name"] || ""

    preview_races =
      if course_id do
        Racing.list_last_races_for_game_event(course_id, 6)
      else
        []
      end

    suggested_name =
      if course_id && current_name == "" do
        course = Enum.find(socket.assigns.courses, &(&1.id == course_id))
        game_type = Enum.find(socket.assigns.game_types, &(&1.id == game_type_id))
        date = Date.utc_today() |> Calendar.strftime("%d/%m/%Y")
        type_label = if game_type, do: game_type.name, else: "Evento"
        if course, do: "#{type_label} - #{course.name} - #{date}", else: ""
      else
        current_name
      end

    form =
      to_form(%{
        "name" => suggested_name,
        "game_type_id" => game_type_id || "",
        "course_id" => course_id || ""
      })

    {:noreply,
     assign(socket,
       form: form,
       selected_course_id: course_id,
       selected_game_type_id: game_type_id,
       preview_races: preview_races
     )}
  end

  def handle_event("create", params, socket) do
    course_id = presence(params["course_id"])
    game_type_id = presence(params["game_type_id"])
    name = String.trim(params["name"] || "")

    with true <- course_id != nil,
         true <- game_type_id != nil,
         config when not is_nil(config) <- Games.get_active_config_for_game_type(game_type_id),
         races when races != [] <- Racing.list_last_races_for_game_event(course_id, 6) do
      attrs = %{
        game_type_id: game_type_id,
        game_config_id: config.id,
        course_id: course_id,
        created_by: socket.assigns.current_scope.user.id,
        name: name
      }

      case Games.create_game_event_with_races(attrs, races) do
        {:ok, %{game_event: event}} ->
          {:noreply,
           socket
           |> put_flash(:info, "Evento \"#{event.name}\" creado con #{length(races)} carreras.")
           |> push_navigate(to: ~p"/admin/eventos/#{event.id}")}

        {:error, _, changeset, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error al crear el evento.")
           |> assign(form: to_form(changeset))}
      end
    else
      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Completa todos los campos y verifica que haya carreras disponibles."
         )}
    end
  end

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(str), do: str
end
