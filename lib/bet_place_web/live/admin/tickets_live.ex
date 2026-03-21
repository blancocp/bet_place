defmodule BetPlaceWeb.Admin.TicketsLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Betting, Games}

  @polla_statuses [:active, :winner, :loser, :refunded]
  @hvh_statuses [:pending, :won, :lost, :void, :refunded]

  # ── Mount ──────────────────────────────────────────────────────────────────

  def mount(_params, _session, socket) do
    polla_all = Betting.list_all_polla_tickets()
    hvh_all = Betting.list_all_hvh_bets()
    events = Games.list_game_events()

    {:ok,
     socket
     |> assign(:tab, :polla)
     |> assign(:polla_all, polla_all)
     |> assign(:hvh_all, hvh_all)
     |> assign(:events, events)
     |> assign(:search, "")
     |> assign(:filter_event, "")
     |> assign(:filter_status, "")
     |> assign(:polla_statuses, @polla_statuses)
     |> assign(:hvh_statuses, @hvh_statuses)
     |> apply_filters()}
  end

  # ── Events ─────────────────────────────────────────────────────────────────

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:search, params["search"] || socket.assigns.search)
     |> assign(:filter_event, params["event_id"] || socket.assigns.filter_event)
     |> assign(:filter_status, params["status"] || socket.assigns.filter_status)
     |> apply_filters()}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:filter_event, "")
     |> assign(:filter_status, "")
     |> apply_filters()}
  end

  # ── Filter logic ───────────────────────────────────────────────────────────

  defp apply_filters(socket) do
    %{
      polla_all: polla_all,
      hvh_all: hvh_all,
      search: search,
      filter_event: event_id,
      filter_status: status
    } = socket.assigns

    q = String.downcase(String.trim(search))

    polla_filtered =
      polla_all
      |> filter_by_user(q)
      |> filter_polla_by_event(event_id)
      |> filter_polla_by_status(status)

    hvh_filtered =
      hvh_all
      |> filter_by_user(q)
      |> filter_hvh_by_event(event_id)
      |> filter_hvh_by_status(status)

    socket
    |> assign(:polla_tickets, polla_filtered)
    |> assign(:hvh_bets, hvh_filtered)
  end

  defp filter_by_user(list, ""), do: list

  defp filter_by_user(list, q),
    do: Enum.filter(list, &String.contains?(String.downcase(&1.user.username), q))

  defp filter_polla_by_event(list, ""), do: list

  defp filter_polla_by_event(list, id),
    do: Enum.filter(list, &(to_string(&1.game_event_id) == id))

  defp filter_hvh_by_event(list, ""), do: list

  defp filter_hvh_by_event(list, id),
    do: Enum.filter(list, &(to_string(&1.hvh_matchup.game_event_id) == id))

  defp filter_polla_by_status(list, ""), do: list

  defp filter_polla_by_status(list, s),
    do: Enum.filter(list, &(to_string(&1.status) == s))

  defp filter_hvh_by_status(list, ""), do: list

  defp filter_hvh_by_status(list, s),
    do: Enum.filter(list, &(to_string(&1.status) == s))

  # ── Render ─────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-3xl font-bold">Tickets colocados</h1>
            <p class="text-base-content/60 mt-1">
              {length(@polla_all)} polla · {length(@hvh_all)} HvH en total
            </p>
          </div>
          <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm gap-1">
            <.icon name="hero-arrow-left" class="size-4" /> Admin
          </.link>
        </div>

        <%!-- Filtros --%>
        <div class="card bg-base-100 border border-base-200 shadow-sm mb-6">
          <div class="card-body p-4">
            <form phx-change="filter" class="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <%!-- Búsqueda por usuario --%>
              <div class="relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-base-content/40"
                />
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="Buscar por usuario..."
                  class="input input-bordered input-sm w-full pl-9"
                  phx-debounce="300"
                />
              </div>
              <%!-- Filtro por evento --%>
              <select name="event_id" class="select select-bordered select-sm w-full">
                <option value="">Todos los eventos</option>
                <option :for={e <- @events} value={e.id} selected={@filter_event == to_string(e.id)}>
                  {e.name}
                </option>
              </select>
              <%!-- Filtro por estado (depende del tab activo) --%>
              <div class="flex gap-2">
                <select name="status" class="select select-bordered select-sm flex-1">
                  <option value="">Todos los estados</option>
                  <%= if @tab == :polla do %>
                    <option
                      :for={s <- @polla_statuses}
                      value={s}
                      selected={@filter_status == to_string(s)}
                    >
                      {polla_label(s)}
                    </option>
                  <% else %>
                    <option
                      :for={s <- @hvh_statuses}
                      value={s}
                      selected={@filter_status == to_string(s)}
                    >
                      {hvh_label(s)}
                    </option>
                  <% end %>
                </select>
                <button
                  :if={@search != "" or @filter_event != "" or @filter_status != ""}
                  type="button"
                  phx-click="clear_filters"
                  class="btn btn-ghost btn-sm"
                  title="Limpiar filtros"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>
            </form>
          </div>
        </div>

        <%!-- Tabs --%>
        <div role="tablist" class="tabs tabs-bordered mb-6">
          <button
            role="tab"
            class={["tab", if(@tab == :polla, do: "tab-active", else: "")]}
            phx-click="switch_tab"
            phx-value-tab="polla"
          >
            La Polla Hípica
            <span class="badge badge-sm ml-2">
              {length(@polla_tickets)}{if length(@polla_tickets) != length(@polla_all),
                do: "/#{length(@polla_all)}",
                else: ""}
            </span>
          </button>
          <button
            role="tab"
            class={["tab", if(@tab == :hvh, do: "tab-active", else: "")]}
            phx-click="switch_tab"
            phx-value-tab="hvh"
          >
            Horse vs Horse
            <span class="badge badge-sm ml-2">
              {length(@hvh_bets)}{if length(@hvh_bets) != length(@hvh_all),
                do: "/#{length(@hvh_all)}",
                else: ""}
            </span>
          </button>
        </div>

        <%!-- Polla Tickets --%>
        <div :if={@tab == :polla}>
          <div :if={@polla_tickets == []} class="text-center text-base-content/50 py-16">
            {if @search != "" or @filter_event != "" or @filter_status != "",
              do: "Sin resultados para los filtros aplicados.",
              else: "No hay tickets registrados."}
          </div>

          <div :if={@polla_tickets != []} class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Usuario</th>
                  <th>Evento</th>
                  <th class="text-center">Comb.</th>
                  <th>Total</th>
                  <th class="text-center">Pts</th>
                  <th class="text-center">Rank</th>
                  <th>Estado</th>
                  <th>Fecha</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={ticket <- @polla_tickets}>
                  <td class="font-mono text-xs text-base-content/40">
                    {String.slice(ticket.id, 0, 8)}…
                  </td>
                  <td class="font-medium">{ticket.user.username}</td>
                  <td>
                    <.link
                      navigate={~p"/admin/eventos/#{ticket.game_event_id}"}
                      class="link link-hover text-sm"
                    >
                      {ticket.game_event.name}
                    </.link>
                  </td>
                  <td class="text-center">{ticket.combination_count}</td>
                  <td>${format_decimal(ticket.total_paid)}</td>
                  <td class="text-center">{ticket.total_points || "—"}</td>
                  <td class="text-center">{ticket.rank || "—"}</td>
                  <td>
                    <span class={polla_badge(ticket.status)}>{polla_label(ticket.status)}</span>
                  </td>
                  <td class="text-xs text-base-content/50">{format_dt(ticket.inserted_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- HvH Bets --%>
        <div :if={@tab == :hvh}>
          <div :if={@hvh_bets == []} class="text-center text-base-content/50 py-16">
            {if @search != "" or @filter_event != "" or @filter_status != "",
              do: "Sin resultados para los filtros aplicados.",
              else: "No hay apuestas HvH registradas."}
          </div>

          <div :if={@hvh_bets != []} class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Usuario</th>
                  <th>Evento</th>
                  <th>Carrera</th>
                  <th>Lado</th>
                  <th>Monto</th>
                  <th>Posible cobro</th>
                  <th>Cobro real</th>
                  <th>Estado</th>
                  <th>Fecha</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={bet <- @hvh_bets}>
                  <td class="font-mono text-xs text-base-content/40">
                    {String.slice(bet.id, 0, 8)}…
                  </td>
                  <td class="font-medium">{bet.user.username}</td>
                  <td class="text-sm">{bet.hvh_matchup.game_event.name}</td>
                  <td class="text-sm text-base-content/60">
                    {bet.hvh_matchup.race.distance_raw || "—"}
                  </td>
                  <td>
                    <span class={
                      if bet.side_chosen == :a,
                        do: "badge badge-primary badge-sm",
                        else: "badge badge-secondary badge-sm"
                    }>
                      {if bet.side_chosen == :a, do: "Macho", else: "Hembra"}
                    </span>
                  </td>
                  <td>${format_decimal(bet.amount)}</td>
                  <td>${format_decimal(bet.potential_payout)}</td>
                  <td>
                    <span :if={bet.status == :won} class="text-success font-bold">
                      ${format_decimal(bet.actual_payout)}
                    </span>
                    <span :if={bet.status != :won}>—</span>
                  </td>
                  <td>
                    <span class={hvh_badge(bet.status)}>{hvh_label(bet.status)}</span>
                  </td>
                  <td class="text-xs text-base-content/50">{format_dt(bet.placed_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(d), do: Decimal.round(d, 2) |> Decimal.to_string()

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")

  defp polla_badge(:active), do: "badge badge-info badge-sm"
  defp polla_badge(:winner), do: "badge badge-success badge-sm"
  defp polla_badge(:loser), do: "badge badge-neutral badge-sm"
  defp polla_badge(:refunded), do: "badge badge-warning badge-sm"
  defp polla_badge(_), do: "badge badge-ghost badge-sm"

  defp polla_label(:active), do: "Activo"
  defp polla_label(:winner), do: "Ganador"
  defp polla_label(:loser), do: "Perdedor"
  defp polla_label(:refunded), do: "Reembolsado"
  defp polla_label(_), do: "—"

  defp hvh_badge(:pending), do: "badge badge-info badge-sm"
  defp hvh_badge(:won), do: "badge badge-success badge-sm"
  defp hvh_badge(:lost), do: "badge badge-neutral badge-sm"
  defp hvh_badge(:void), do: "badge badge-warning badge-sm"
  defp hvh_badge(:refunded), do: "badge badge-warning badge-sm"
  defp hvh_badge(_), do: "badge badge-ghost badge-sm"

  defp hvh_label(:pending), do: "Pendiente"
  defp hvh_label(:won), do: "Ganado"
  defp hvh_label(:lost), do: "Perdido"
  defp hvh_label(:void), do: "Nulo"
  defp hvh_label(:refunded), do: "Reembolsado"
  defp hvh_label(_), do: "—"
end
