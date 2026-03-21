defmodule BetPlaceWeb.Bettor.MyTicketsLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Betting

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    polla_tickets = Betting.list_polla_tickets_for_user(user_id)
    hvh_bets = Betting.list_hvh_bets_for_user(user_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(BetPlace.PubSub, "user:#{user_id}")
    end

    {:ok,
     socket
     |> assign(:polla_tickets, polla_tickets)
     |> assign(:hvh_bets, hvh_bets)
     |> assign(:expanded_combo_ids, MapSet.new())}
  end

  def handle_event("toggle_combo_detail", %{"combo_id" => combo_id}, socket) do
    ids = socket.assigns.expanded_combo_ids

    new_ids =
      if MapSet.member?(ids, combo_id),
        do: MapSet.delete(ids, combo_id),
        else: MapSet.put(ids, combo_id)

    {:noreply, assign(socket, :expanded_combo_ids, new_ids)}
  end

  def handle_info({:balance_updated, _new_balance}, socket) do
    user_id = socket.assigns.current_scope.user.id

    updated_user = BetPlace.Accounts.get_user!(user_id)

    {:noreply,
     socket
     |> assign(:current_scope, BetPlace.Accounts.build_scope(updated_user))
     |> assign(:polla_tickets, Betting.list_polla_tickets_for_user(user_id))
     |> assign(:hvh_bets, Betting.list_hvh_bets_for_user(user_id))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold">Mis apuestas</h1>
          <.link navigate={~p"/historial"} class="btn btn-outline btn-sm gap-1">
            <.icon name="hero-clock" class="size-4" /> Ver historial completo
          </.link>
        </div>

        <%!-- Polla tickets --%>
        <section class="mb-10">
          <h2 class="text-lg font-semibold mb-3">La Polla Hípica</h2>

          <div :if={@polla_tickets == []} class="text-base-content/50 text-center py-8">
            No tienes tickets registrados.
          </div>

          <div :if={@polla_tickets != []} class="space-y-6">
            <div
              :for={ticket <- @polla_tickets}
              class="card bg-base-100 border border-base-200 shadow-sm"
            >
              <div class="card-body p-4">
                <div class="flex flex-wrap items-center justify-between gap-2 mb-3">
                  <.link
                    navigate={~p"/eventos/#{ticket.game_event_id}"}
                    class="link link-hover font-semibold"
                  >
                    {ticket.game_event.name}
                  </.link>
                  <div class="flex items-center gap-2">
                    <span class={polla_status_badge(ticket.status)}>
                      {polla_status_label(ticket.status)}
                    </span>
                    <span class="text-sm text-base-content/60">
                      {format_date(ticket.inserted_at)}
                    </span>
                  </div>
                </div>
                <div class="flex flex-wrap gap-4 text-sm mb-3">
                  <span>{ticket.combination_count} combinaciones</span>
                  <span>${format_decimal(ticket.total_paid)} pagado</span>
                  <span :if={ticket.total_points}>Total: {ticket.total_points} pts</span>
                  <span :if={ticket.status == :winner} class="text-success font-bold">
                    Premio: ${format_decimal(best_prize(ticket))}
                  </span>
                </div>
                <% points_lookup = selection_points_lookup(ticket) %>
                <div class="space-y-2">
                  <div
                    :for={combo <- combo_cards_for_ticket(ticket)}
                    class="rounded-lg border border-base-200 bg-base-200/50 p-3"
                  >
                    <div
                      class="flex items-center justify-between gap-2 cursor-pointer"
                      phx-click="toggle_combo_detail"
                      phx-value-combo_id={combo.id}
                    >
                      <span class="font-mono font-semibold">{combo_string(combo)}</span>
                      <div class="flex items-center gap-2">
                        <span class="badge badge-ghost badge-sm">{combo.total_points} pts</span>
                        <span
                          :if={combo.is_winner && combo.prize_amount}
                          class="text-success font-bold text-xs"
                        >
                          ${format_decimal(combo.prize_amount)}
                        </span>
                        <.icon
                          name={
                            if MapSet.member?(@expanded_combo_ids, combo.id),
                              do: "hero-chevron-up",
                              else: "hero-chevron-down"
                          }
                          class="w-4 h-4 text-base-content/40"
                        />
                      </div>
                    </div>
                    <div
                      :if={MapSet.member?(@expanded_combo_ids, combo.id)}
                      class="mt-3 pt-3 border-t border-base-300"
                    >
                      <p class="text-xs text-base-content/50 uppercase tracking-wide mb-2">
                        Detalle por válida
                      </p>
                      <div class="grid grid-cols-3 gap-x-4 gap-y-1 text-xs">
                        <div :for={cs <- combo_selections_sorted(combo)} class="flex justify-between">
                          <span class="text-base-content/60">{cs.game_event_race.race_order}V</span>
                          <span class="font-medium">{cs.runner.program_number}</span>
                          <span class={
                            points_result_class(
                              Map.get(points_lookup, {cs.game_event_race_id, cs.runner_id}, 0)
                            )
                          }>
                            {points_to_result(
                              Map.get(points_lookup, {cs.game_event_race_id, cs.runner_id}, 0)
                            )}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- HvH bets --%>
        <section>
          <h2 class="text-lg font-semibold mb-3">Horse vs Horse</h2>

          <div :if={@hvh_bets == []} class="text-base-content/50 text-center py-8">
            No tienes apuestas HvH registradas.
          </div>

          <div class="overflow-x-auto">
            <table :if={@hvh_bets != []} class="table table-zebra w-full">
              <thead>
                <tr>
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
                  <td class="text-sm">{bet.hvh_matchup.race.distance_raw || "—"}</td>
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
                    <span class={hvh_bet_status_badge(bet.status)}>
                      {hvh_bet_status_label(bet.status)}
                    </span>
                  </td>
                  <td class="text-xs text-base-content/60">{format_date(bet.inserted_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp best_prize(ticket) do
    ticket.polla_combinations
    |> Enum.filter(& &1.is_winner)
    |> Enum.map(& &1.prize_amount)
    |> Enum.max(Decimal, fn -> Decimal.new("0") end)
  rescue
    _ -> Decimal.new("0")
  end

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(d), do: Decimal.round(d, 2) |> Decimal.to_string()

  defp format_date(nil), do: "—"
  defp format_date(dt), do: Calendar.strftime(dt, "%d/%m/%Y")

  defp polla_status_badge(:active), do: "badge badge-info badge-sm"
  defp polla_status_badge(:winner), do: "badge badge-success badge-sm"
  defp polla_status_badge(:loser), do: "badge badge-neutral badge-sm"
  defp polla_status_badge(:refunded), do: "badge badge-warning badge-sm"
  defp polla_status_badge(_), do: "badge badge-ghost badge-sm"

  defp polla_status_label(:active), do: "Activo"
  defp polla_status_label(:winner), do: "Ganador"
  defp polla_status_label(:loser), do: "Perdedor"
  defp polla_status_label(:refunded), do: "Reembolsado"
  defp polla_status_label(_), do: "—"

  defp hvh_bet_status_badge(:pending), do: "badge badge-info badge-sm"
  defp hvh_bet_status_badge(:won), do: "badge badge-success badge-sm"
  defp hvh_bet_status_badge(:lost), do: "badge badge-neutral badge-sm"
  defp hvh_bet_status_badge(:void), do: "badge badge-warning badge-sm"
  defp hvh_bet_status_badge(:refunded), do: "badge badge-warning badge-sm"
  defp hvh_bet_status_badge(_), do: "badge badge-ghost badge-sm"

  defp hvh_bet_status_label(:pending), do: "Pendiente"
  defp hvh_bet_status_label(:won), do: "Ganado"
  defp hvh_bet_status_label(:lost), do: "Perdido"
  defp hvh_bet_status_label(:void), do: "Nulo"
  defp hvh_bet_status_label(:refunded), do: "Reembolsado"
  defp hvh_bet_status_label(_), do: "—"

  defp selection_points_lookup(ticket) do
    Map.new(ticket.polla_selections || [], fn s ->
      {{s.game_event_race_id, s.runner_id}, s.points_earned}
    end)
  end

  defp combo_cards_for_ticket(ticket) do
    (ticket.polla_combinations || []) |> Enum.sort_by(& &1.combination_index)
  end

  defp combo_string(combo) do
    sorted = combo_selections_sorted(combo)

    if sorted == [],
      do: "—",
      else: Enum.map_join(sorted, "-", fn cs -> to_string(cs.runner.program_number) end)
  end

  defp combo_selections_sorted(combo) do
    Enum.sort_by(combo.polla_combination_selections || [], & &1.game_event_race.race_order)
  end

  defp points_to_result(5), do: "1º"
  defp points_to_result(3), do: "2º"
  defp points_to_result(1), do: "3º"
  defp points_to_result(_), do: "X"

  defp points_result_class(5), do: "text-success font-medium"
  defp points_result_class(3), do: "text-info font-medium"
  defp points_result_class(1), do: "text-warning font-medium"
  defp points_result_class(_), do: "text-base-content/40"
end
