defmodule BetPlaceWeb.Bettor.BettingHistoryLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Betting, Games}

  @polla_statuses [:active, :winner, :loser, :refunded]
  @hvh_statuses [:pending, :won, :lost, :void, :refunded]

  # ── Mount ──────────────────────────────────────────────────────────────────

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    hvh_all = Betting.list_hvh_bets_for_user(user_id)
    finished_events = Games.list_recent_finished_game_events(20)
    selected_event = Games.get_last_finished_game_event()
    selected_event_id = if selected_event, do: selected_event.id, else: nil

    my_polla_tickets =
      if selected_event_id do
        Betting.list_polla_tickets_for_user_and_event(user_id, selected_event_id)
      else
        []
      end

    leaderboard_rows =
      if selected_event_id do
        Betting.list_leaderboard_rows(selected_event_id)
      else
        []
      end

    counts =
      if selected_event_id do
        Betting.get_polla_event_counts(selected_event_id)
      else
        %{ticket_count: 0, combination_count: 0}
      end

    {:ok,
     socket
     |> assign(:tab, :polla)
     |> assign(:hvh_all, hvh_all)
     |> assign(:polla_statuses, @polla_statuses)
     |> assign(:hvh_statuses, @hvh_statuses)
     |> assign(:finished_events, finished_events)
     |> assign(:selected_event, selected_event)
     |> assign(:selected_event_id, selected_event_id)
     |> assign(:my_polla_tickets, my_polla_tickets)
     |> assign(:leaderboard_rows, leaderboard_rows)
     |> assign(:polla_counts, counts)
     |> assign(:hvh_bets, hvh_all)}
  end

  # ── Events ─────────────────────────────────────────────────────────────────

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  def handle_event("select_event", %{"event_id" => event_id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    selected_event =
      Enum.find(socket.assigns.finished_events, fn e -> to_string(e.id) == event_id end)

    selected_event_id = selected_event && selected_event.id

    my_polla_tickets =
      if selected_event_id do
        Betting.list_polla_tickets_for_user_and_event(user_id, selected_event_id)
      else
        []
      end

    leaderboard_rows =
      if selected_event_id do
        Betting.list_leaderboard_rows(selected_event_id)
      else
        []
      end

    counts =
      if selected_event_id do
        Betting.get_polla_event_counts(selected_event_id)
      else
        %{ticket_count: 0, combination_count: 0}
      end

    {:noreply,
     socket
     |> assign(:selected_event, selected_event)
     |> assign(:selected_event_id, selected_event_id)
     |> assign(:my_polla_tickets, my_polla_tickets)
     |> assign(:leaderboard_rows, leaderboard_rows)
     |> assign(:polla_counts, counts)}
  end

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
              {length(@my_polla_tickets)} tickets (evento) · {length(@hvh_all)} apuestas HvH
            </p>
          </div>
          <.link navigate={~p"/eventos"} class="btn btn-ghost btn-sm gap-1">
            <.icon name="hero-arrow-left" class="size-4" /> Eventos
          </.link>
        </div>

        <%!-- Selector de evento finalizado (Polla) --%>
        <div :if={@tab == :polla} class="card bg-base-100 border border-base-200 shadow-sm mb-6">
          <div class="card-body p-4">
            <div class="flex flex-col sm:flex-row gap-3 sm:items-end">
              <div class="flex-1">
                <label class="label text-xs pb-1">Evento finalizado</label>
                <select
                  class="select select-bordered select-sm w-full"
                  phx-change="select_event"
                  name="event_id"
                >
                  <option :if={@finished_events == []} value="">No hay eventos finalizados</option>
                  <option
                    :for={e <- @finished_events}
                    value={e.id}
                    selected={@selected_event_id == e.id}
                  >
                    {e.name}
                  </option>
                </select>
              </div>
              <div class="text-xs text-base-content/60">
                <span :if={@selected_event}>Curso: {@selected_event.course.full_name}</span>
              </div>
            </div>
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
            La Polla Hípica <span class="badge badge-sm ml-2">{length(@my_polla_tickets)}</span>
          </button>
          <button
            role="tab"
            class={["tab", if(@tab == :hvh, do: "tab-active", else: "")]}
            phx-click="switch_tab"
            phx-value-tab="hvh"
          >
            Horse vs Horse <span class="badge badge-sm ml-2">{length(@hvh_bets)}</span>
          </button>
        </div>

        <div :if={@tab == :polla}>
          <%!-- Mis tickets (solo evento seleccionado) --%>
          <section class="mb-8">
            <div class="flex items-center justify-between mb-3">
              <h2 class="text-lg font-semibold">Mis tickets</h2>
              <span class="badge badge-ghost badge-sm">
                {@polla_counts.ticket_count} selladas · {@polla_counts.combination_count} combinaciones
              </span>
            </div>

            <div :if={@my_polla_tickets == []} class="text-center text-base-content/50 py-10">
              {if @selected_event,
                do: "No tienes tickets en este evento.",
                else: "Selecciona un evento finalizado."}
            </div>

            <div :if={@my_polla_tickets != []} class="space-y-4">
              <div
                :for={ticket <- @my_polla_tickets}
                class="card bg-base-100 border border-base-200 shadow-sm"
              >
                <div class="card-body p-4">
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

                  <div class="flex flex-wrap gap-4 text-sm">
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
                </div>
              </div>
            </div>
          </section>

          <%!-- Resumen global (todos los bettors) --%>
          <section>
            <h2 class="text-lg font-semibold mb-3">Resumen del evento (todos)</h2>

            <div :if={@leaderboard_rows == []} class="text-center text-base-content/50 py-10">
              {if @selected_event,
                do: "Aún no hay resultados para este evento.",
                else: "Selecciona un evento finalizado."}
            </div>

            <div
              :if={@leaderboard_rows != []}
              class="overflow-x-auto rounded-lg border border-base-200"
            >
              <table class="table table-zebra table-sm w-full">
                <thead>
                  <tr>
                    <th class="sticky left-0 bg-base-200 z-10">Usuario</th>
                    <th
                      :for={i <- 1..leaderboard_num_races(@leaderboard_rows)}
                      class="text-center"
                      colspan="2"
                    >
                      C{i}
                    </th>
                    <th class="text-center font-bold">Total</th>
                  </tr>
                  <tr>
                    <th class="sticky left-0 bg-base-200 z-10"></th>
                    <th
                      :for={_i <- 1..leaderboard_num_races(@leaderboard_rows)}
                      class="text-center text-xs"
                    >
                      E
                    </th>
                    <th
                      :for={_i <- 1..leaderboard_num_races(@leaderboard_rows)}
                      class="text-center text-xs"
                    >
                      Pt
                    </th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- @leaderboard_rows}>
                    <td class="font-medium sticky left-0 bg-base-100 z-10">{row.username}</td>
                    <%= for r <- row.races do %>
                      <td class="text-center text-sm">{r.selection || "—"}</td>
                      <td class="text-center text-sm">{r.points}</td>
                    <% end %>
                    <td class="text-center font-bold">{row.total_points}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
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

  defp leaderboard_num_races([]), do: 0
  defp leaderboard_num_races([row | _]), do: length(row.races)
end
