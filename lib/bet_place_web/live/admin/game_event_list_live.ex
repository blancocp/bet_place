defmodule BetPlaceWeb.Admin.GameEventListLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Games

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-3xl font-bold">Eventos de apuestas</h1>
          <.link navigate={~p"/admin/eventos/nuevo"} class="btn btn-primary btn-sm gap-2">
            <.icon name="hero-plus" class="size-4" /> Crear evento
          </.link>
        </div>

        <div class="card bg-base-100 border border-base-200 shadow-sm overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Juego</th>
                <th>Hipódromo</th>
                <th>Cierra apuestas</th>
                <th>Estado</th>
                <th></th>
              </tr>
            </thead>
            <tbody id="events" phx-update="stream">
              <tr class="hidden only:table-row">
                <td colspan="6" class="text-center text-base-content/50 py-8">
                  No hay eventos creados aún.
                </td>
              </tr>
              <tr :for={{id, event} <- @streams.events} id={id} class="hover">
                <td class="font-medium">{event.name}</td>
                <td>
                  <span class="badge badge-outline badge-sm">
                    {event.game_type.name}
                  </span>
                </td>
                <td class="text-sm text-base-content/70">{event.course.full_name}</td>
                <td class="text-sm">
                  {if event.betting_closes_at,
                    do: Calendar.strftime(event.betting_closes_at, "%d/%m/%Y %H:%M"),
                    else: "—"}
                </td>
                <td>
                  <span class={["badge badge-sm", status_badge_class(event.status)]}>
                    {status_label(event.status)}
                  </span>
                </td>
                <td>
                  <.link navigate={~p"/admin/eventos/#{event.id}"} class="btn btn-ghost btn-xs">
                    Ver
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    events = Games.list_game_events()
    {:ok, stream(socket, :events, events)}
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
end
