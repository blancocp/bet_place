defmodule BetPlaceWeb.Bettor.BettingHistoryLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Betting, Games}

  @polla_statuses [:active, :winner, :loser, :refunded]
  @hvh_statuses [:pending, :won, :lost, :void, :refunded]

  # ── Mount ──────────────────────────────────────────────────────────────────

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    polla_all = Betting.list_polla_tickets_for_user(user_id)
    hvh_all = Betting.list_hvh_bets_for_user(user_id)
    events = Games.list_game_events()

    {:ok,
     socket
     |> assign(:tab, :polla)
     |> assign(:polla_all, polla_all)
     |> assign(:hvh_all, hvh_all)
     |> assign(:events, events)
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
     |> assign(:filter_event, params["event_id"] || socket.assigns.filter_event)
     |> assign(:filter_status, params["status"] || socket.assigns.filter_status)
     |> apply_filters()}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply,
     socket
     |> assign(:filter_event, "")
     |> assign(:filter_status, "")
     |> apply_filters()}
  end

  # ── Filter logic ───────────────────────────────────────────────────────────

  defp apply_filters(socket) do
    %{polla_all: polla_all, hvh_all: hvh_all, filter_event: event_id, filter_status: status} =
      socket.assigns

    polla_filtered =
      polla_all
      |> filter_polla_by_event(event_id)
      |> filter_by_status(status)

    hvh_filtered =
      hvh_all
      |> filter_hvh_by_event(event_id)
      |> filter_by_status(status)

    socket
    |> assign(:polla_tickets, polla_filtered)
    |> assign(:hvh_bets, hvh_filtered)
  end

  defp filter_polla_by_event(list, ""), do: list

  defp filter_polla_by_event(list, id),
    do: Enum.filter(list, &(to_string(&1.game_event_id) == id))

  defp filter_hvh_by_event(list, ""), do: list

  defp filter_hvh_by_event(list, id),
    do: Enum.filter(list, &(to_string(&1.hvh_matchup.game_event_id) == id))

  defp filter_by_status(list, ""), do: list

  defp filter_by_status(list, s),
    do: Enum.filter(list, &(to_string(&1.status) == s))

  # ── Render ─────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-3xl font-bold">Historial de apuestas</h1>
            <p class="text-base-content/60 mt-1">
              {length(@polla_all)} tickets polla · {length(@hvh_all)} apuestas HvH
            </p>
          </div>
          <.link navigate={~p"/eventos"} class="btn btn-ghost btn-sm gap-1">
            <.icon name="hero-arrow-left" class="size-4" /> Eventos
          </.link>
        </div>

        <%!-- Filtros --%>
        <div class="card bg-base-100 border border-base-200 shadow-sm mb-6">
          <div class="card-body p-4">
            <form phx-change="filter" class="flex flex-col sm:flex-row gap-3">
              <select name="event_id" class="select select-bordered select-sm flex-1">
                <option value="">Todos los eventos</option>
                <option
                  :for={e <- @events}
                  value={e.id}
                  selected={@filter_event == to_string(e.id)}
                >
                  {e.name}
                </option>
              </select>

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
                  :if={@filter_event != "" or @filter_status != ""}
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
            {if @filter_event != "" or @filter_status != "",
              do: "Sin resultados para los filtros aplicados.",
              else: "Aún no tienes tickets registrados."}
          </div>

          <div class="space-y-4">
            <div
              :for={ticket <- @polla_tickets}
              class="card bg-base-100 border border-base-200 shadow-sm"
            >
              <div class="card-body p-4">
                <%!-- Ticket header --%>
                <div class="flex items-start justify-between gap-2 mb-3">
                  <div>
                    <.link
                      navigate={~p"/eventos/#{ticket.game_event_id}"}
                      class="font-bold link link-hover"
                    >
                      {ticket.game_event.name}
                    </.link>
                    <p class="text-xs text-base-content/50 mt-0.5">
                      #{String.slice(ticket.id, 0, 8)} · {format_dt(ticket.inserted_at)}
                    </p>
                  </div>
                  <span class={polla_badge(ticket.status)}>{polla_label(ticket.status)}</span>
                </div>

                <%!-- Stats row --%>
                <div class="flex flex-wrap gap-4 text-sm mb-3">
                  <div>
                    <span class="text-base-content/60">Combinaciones</span>
                    <span class="font-bold ml-1">{ticket.combination_count}</span>
                  </div>
                  <div>
                    <span class="text-base-content/60">Total pagado</span>
                    <span class="font-bold ml-1">${format_decimal(ticket.total_paid)}</span>
                  </div>
                  <div :if={ticket.total_points}>
                    <span class="text-base-content/60">Puntos</span>
                    <span class="font-bold ml-1">{ticket.total_points}</span>
                  </div>
                  <div :if={ticket.rank}>
                    <span class="text-base-content/60">Rank</span>
                    <span class="font-bold ml-1">#{ticket.rank}</span>
                  </div>
                </div>

                <%!-- Combinations detail --%>
                <div :if={ticket.polla_combinations != []} class="space-y-1">
                  <p class="text-xs text-base-content/50 font-medium uppercase tracking-wide mb-1">
                    Combinaciones
                  </p>
                  <div
                    :for={combo <- Enum.sort_by(ticket.polla_combinations, & &1.inserted_at)}
                    class={[
                      "flex items-center justify-between text-xs px-2 py-1 rounded",
                      if(combo.is_winner,
                        do: "bg-success/10 border border-success/30",
                        else: "bg-base-200"
                      )
                    ]}
                  >
                    <span class="font-mono text-base-content/60">
                      #{String.slice(combo.id, 0, 6)}
                    </span>
                    <span :if={combo.points} class="font-medium">{combo.points} pts</span>
                    <span :if={combo.is_winner} class="text-success font-bold">
                      ${format_decimal(combo.prize_amount)}
                    </span>
                    <span :if={!combo.is_winner and combo.points} class="text-base-content/40">
                      Sin premio
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- HvH Bets --%>
        <div :if={@tab == :hvh}>
          <div :if={@hvh_bets == []} class="text-center text-base-content/50 py-16">
            {if @filter_event != "" or @filter_status != "",
              do: "Sin resultados para los filtros aplicados.",
              else: "Aún no tienes apuestas HvH registradas."}
          </div>

          <div class="space-y-3">
            <div
              :for={bet <- @hvh_bets}
              class="card bg-base-100 border border-base-200 shadow-sm"
            >
              <div class="card-body p-4">
                <div class="flex items-start justify-between gap-2">
                  <div class="flex-1">
                    <p class="font-medium text-sm">
                      {bet.hvh_matchup.race.distance_raw || "Carrera"}
                    </p>
                    <p class="text-xs text-base-content/50 mt-0.5">
                      {format_dt(bet.placed_at)}
                    </p>
                  </div>
                  <span class={hvh_badge(bet.status)}>{hvh_label(bet.status)}</span>
                </div>

                <div class="flex flex-wrap gap-4 text-sm mt-2">
                  <div>
                    <span class="text-base-content/60">Lado</span>
                    <span class={[
                      "badge badge-sm ml-1",
                      if(bet.side_chosen == :a, do: "badge-primary", else: "badge-secondary")
                    ]}>
                      {if bet.side_chosen == :a, do: "A", else: "B"}
                    </span>
                  </div>
                  <div>
                    <span class="text-base-content/60">Apostado</span>
                    <span class="font-bold ml-1">${format_decimal(bet.amount)}</span>
                  </div>
                  <div>
                    <span class="text-base-content/60">Posible cobro</span>
                    <span class="font-medium ml-1">${format_decimal(bet.potential_payout)}</span>
                  </div>
                  <div :if={bet.status == :won} class="text-success">
                    <span>Cobrado</span>
                    <span class="font-bold ml-1">${format_decimal(bet.actual_payout)}</span>
                  </div>
                </div>
              </div>
            </div>
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
