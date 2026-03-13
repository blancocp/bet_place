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
     |> assign(:hvh_bets, hvh_bets)}
  end

  def handle_info({:balance_updated, _new_balance}, socket) do
    user_id = socket.assigns.current_scope.user.id

    {:noreply,
     socket
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

          <div class="overflow-x-auto">
            <table :if={@polla_tickets != []} class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Evento</th>
                  <th>Combinaciones</th>
                  <th>Total pagado</th>
                  <th>Puntos</th>
                  <th>Premio</th>
                  <th>Estado</th>
                  <th>Fecha</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={ticket <- @polla_tickets}>
                  <td class="font-medium">
                    <.link navigate={~p"/eventos/#{ticket.game_event_id}"} class="link link-hover">
                      {ticket.game_event.name}
                    </.link>
                  </td>
                  <td>{ticket.combination_count}</td>
                  <td>${format_decimal(ticket.total_paid)}</td>
                  <td>{ticket.total_points || "—"}</td>
                  <td>
                    <span :if={ticket.status == :winner} class="text-success font-bold">
                      ${format_decimal(best_prize(ticket))}
                    </span>
                    <span :if={ticket.status != :winner}>—</span>
                  </td>
                  <td>
                    <span class={polla_status_badge(ticket.status)}>
                      {polla_status_label(ticket.status)}
                    </span>
                  </td>
                  <td class="text-xs text-base-content/60">{format_date(ticket.inserted_at)}</td>
                </tr>
              </tbody>
            </table>
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
                      {if bet.side_chosen == :a, do: "Lado A", else: "Lado B"}
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
end
