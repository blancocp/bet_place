defmodule BetPlaceWeb.Bettor.GameEventShowLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Games
  alias BetPlace.Betting
  alias BetPlace.Racing

  @tick_interval 1_000

  # ── Mount ─────────────────────────────────────────────────────────────────

  def mount(%{"id" => id}, _session, socket) do
    event = Games.get_game_event!(id)

    races_with_runners =
      event.game_event_races
      |> Enum.sort_by(& &1.race_order)
      |> Enum.map(fn ger ->
        runners =
          ger.race_id
          |> Racing.list_runners_for_race()
          |> Enum.reject(& &1.non_runner)
          |> Enum.sort_by(& &1.program_number)

        {ger, runners}
      end)

    matchups = Betting.list_hvh_matchups_for_event(event.id)

    if connected?(socket) do
      Process.send_after(self(), :tick, @tick_interval)
      Phoenix.PubSub.subscribe(BetPlace.PubSub, "game_event:#{event.id}")
    end

    user_id = socket.assigns.current_scope.user.id

    {:ok,
     socket
     |> assign(:event, event)
     |> assign(:races_with_runners, races_with_runners)
     |> assign(:matchups, matchups)
     |> assign(:hvh_selections, %{})
     |> assign(:selections, %{})
     |> assign(:combination_count, 0)
     |> assign(:total_paid, Decimal.new("0.00"))
     |> assign(:can_submit, false)
     |> assign(:show_confirm, false)
     |> assign(:placing, false)
     |> assign(:time_remaining, time_remaining(event.betting_closes_at))
     |> assign(:show_my_tickets, false)
     |> assign(
       :my_polla_tickets,
       Betting.list_polla_tickets_for_user_and_event(user_id, event.id)
     )
     |> assign(:my_hvh_bets, Betting.list_hvh_bets_for_user_and_event(user_id, event.id))}
  end

  # ── Events ────────────────────────────────────────────────────────────────

  def handle_event("toggle_runner", %{"race_id" => race_id, "runner_id" => runner_id}, socket) do
    max = socket.assigns.event.game_config.max_horses_per_race || 3
    selections = socket.assigns.selections
    race_set = Map.get(selections, race_id, MapSet.new())

    new_race_set =
      if MapSet.member?(race_set, runner_id) do
        MapSet.delete(race_set, runner_id)
      else
        if MapSet.size(race_set) >= max, do: race_set, else: MapSet.put(race_set, runner_id)
      end

    new_selections = Map.put(selections, race_id, new_race_set)
    {count, total, can_submit} = compute_totals(new_selections, socket.assigns)

    {:noreply,
     socket
     |> assign(:selections, new_selections)
     |> assign(:combination_count, count)
     |> assign(:total_paid, total)
     |> assign(:can_submit, can_submit)}
  end

  def handle_event("open_my_tickets", _, socket) do
    {:noreply, assign(socket, :show_my_tickets, true)}
  end

  def handle_event("close_my_tickets", _, socket) do
    {:noreply, assign(socket, :show_my_tickets, false)}
  end

  def handle_event("show_confirm", _, socket) do
    if socket.assigns.can_submit do
      {:noreply, assign(socket, :show_confirm, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("hide_confirm", _, socket) do
    {:noreply, assign(socket, :show_confirm, false)}
  end

  def handle_event("place_ticket", _, socket) do
    %{event: event, selections: selections, current_scope: scope} = socket.assigns
    user_id = scope.user.id
    selections_map = Map.new(selections, fn {k, v} -> {k, MapSet.to_list(v)} end)

    socket = assign(socket, :placing, true)

    case Betting.place_polla_ticket(user_id, event, selections_map) do
      {:ok, %{ticket: ticket, debit_user: updated_user}} ->
        ticket_ref = String.slice(ticket.id, 0, 8)
        user_id = updated_user.id

        {:noreply,
         socket
         |> assign(:placing, false)
         |> assign(:show_confirm, false)
         |> assign(:selections, %{})
         |> assign(:combination_count, 0)
         |> assign(:total_paid, Decimal.new("0.00"))
         |> assign(:can_submit, false)
         |> update(:current_scope, fn s -> %{s | user: updated_user} end)
         |> assign(
           :my_polla_tickets,
           Betting.list_polla_tickets_for_user_and_event(user_id, socket.assigns.event.id)
         )
         |> put_flash(:info, "¡Ticket #{ticket_ref} registrado con éxito!")}

      {:error, :check_event, reason, _} ->
        msg =
          case reason do
            :betting_closed -> "Las apuestas para este evento ya cerraron."
            :event_not_open -> "Este evento no está disponible."
            :no_selections -> "Debes seleccionar al menos un caballo por carrera."
            _ -> "Error al procesar el ticket."
          end

        {:noreply, socket |> assign(:placing, false) |> put_flash(:error, msg)}

      {:error, :check_balance, :insufficient_balance, _} ->
        {:noreply,
         socket
         |> assign(:placing, false)
         |> put_flash(:error, "Saldo insuficiente para cubrir el total del ticket.")}

      {:error, _, _, _} ->
        {:noreply,
         socket
         |> assign(:placing, false)
         |> put_flash(:error, "Error inesperado. Intenta de nuevo.")}
    end
  end

  def handle_event("hvh_select_side", %{"matchup_id" => mid, "side" => side}, socket) do
    side_atom = if side == "a", do: :a, else: :b
    current = Map.get(socket.assigns.hvh_selections, mid, %{side: nil, amount: ""})

    new_current =
      if current.side == side_atom,
        do: %{side: nil, amount: current.amount},
        else: %{current | side: side_atom}

    {:noreply,
     assign(socket, :hvh_selections, Map.put(socket.assigns.hvh_selections, mid, new_current))}
  end

  def handle_event("hvh_set_amount", %{"matchup_id" => mid, "amount" => amount}, socket) do
    current = Map.get(socket.assigns.hvh_selections, mid, %{side: nil, amount: ""})

    {:noreply,
     assign(
       socket,
       :hvh_selections,
       Map.put(socket.assigns.hvh_selections, mid, %{current | amount: amount})
     )}
  end

  def handle_event("place_hvh_bet", %{"matchup_id" => mid}, socket) do
    %{hvh_selections: hvh_selections, matchups: matchups, current_scope: scope} = socket.assigns
    sel = Map.get(hvh_selections, mid, %{})
    matchup = Enum.find(matchups, &(to_string(&1.id) == mid))

    with %{side: side, amount: amount_str} when not is_nil(side) <- sel,
         {amount_dec, ""} <- Decimal.parse(amount_str),
         true <- Decimal.compare(amount_dec, Decimal.new("0")) == :gt,
         matchup when not is_nil(matchup) <- matchup do
      # Preload game_event with config for place_hvh_bet
      matchup_loaded = %{matchup | game_event: socket.assigns.event}

      case Betting.place_hvh_bet(scope.user.id, matchup_loaded, side, amount_dec) do
        {:ok, %{debit_user: updated_user}} ->
          user_id = updated_user.id

          {:noreply,
           socket
           |> assign(:hvh_selections, Map.delete(hvh_selections, mid))
           |> update(:current_scope, fn s -> %{s | user: updated_user} end)
           |> assign(
             :my_hvh_bets,
             Betting.list_hvh_bets_for_user_and_event(user_id, socket.assigns.event.id)
           )
           |> put_flash(:info, "¡Apuesta HvH registrada!")}

        {:error, :check_matchup, reason, _} ->
          msg =
            if reason == :matchup_not_open,
              do: "Este enfrentamiento ya no está disponible.",
              else: "Evento cerrado."

          {:noreply, put_flash(socket, :error, msg)}

        {:error, :check_balance, _, _} ->
          {:noreply, put_flash(socket, :error, "Saldo insuficiente.")}

        {:error, _, _, _} ->
          {:noreply, put_flash(socket, :error, "Error inesperado.")}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Selecciona un lado y un monto válido.")}
    end
  end

  # ── Info ──────────────────────────────────────────────────────────────────

  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, @tick_interval)

    {:noreply,
     assign(socket, :time_remaining, time_remaining(socket.assigns.event.betting_closes_at))}
  end

  def handle_info({:game_event_update, event}, socket) do
    {:noreply, assign(socket, :event, event)}
  end

  # ── Template ──────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="pb-32">
        <%!-- Header --%>
        <div class="flex items-start justify-between gap-4 mb-6">
          <div>
            <h1 class="text-2xl font-bold">{@event.name}</h1>
            <p class="text-base-content/60 mt-1">{@event.course.full_name}</p>
          </div>
          <div class="text-right shrink-0 flex flex-col items-end gap-2">
            <span class={event_status_badge(@event.status)}>{status_label(@event.status)}</span>
            <div class="text-2xl font-mono font-bold tabular-nums">
              {format_countdown(@time_remaining)}
            </div>
            <p class="text-xs text-base-content/50">hasta cerrar apuestas</p>
            <button
              phx-click="open_my_tickets"
              class="btn btn-sm btn-outline gap-1 mt-1"
            >
              <.icon name="hero-ticket" class="size-4" /> Mis tickets
              <span
                :if={length(@my_polla_tickets) + length(@my_hvh_bets) > 0}
                class="badge badge-sm badge-primary"
              >
                {length(@my_polla_tickets) + length(@my_hvh_bets)}
              </span>
            </button>
          </div>
        </div>

        <%!-- Info strip --%>
        <div class="flex gap-4 mb-6 text-sm text-base-content/60">
          <span>
            Valor ticket:
            <strong class="text-base-content">
              ${format_decimal(@event.game_config.ticket_value)}
            </strong>
          </span>
          <span>
            Max por carrera:
            <strong class="text-base-content">{@event.game_config.max_horses_per_race || 3}</strong>
          </span>
          <span>
            Bote: <strong class="text-base-content">${format_decimal(@event.total_pool)}</strong>
          </span>
        </div>

        <%!-- Races --%>
        <div class="grid gap-4">
          <div
            :for={{event_race, runners} <- @races_with_runners}
            class="card bg-base-100 border border-base-200 shadow"
          >
            <div class="card-body p-4">
              <%!-- Race header --%>
              <div class="flex items-center justify-between mb-3">
                <h2 class="font-bold">
                  Carrera {event_race.race_order}
                  <span class="font-normal text-base-content/60 ml-2">
                    {event_race.race.distance_raw}
                  </span>
                </h2>
                <span class={[
                  "badge badge-sm",
                  if(race_complete?(@selections, event_race.id, runners),
                    do: "badge-success",
                    else: "badge-ghost"
                  )
                ]}>
                  {selected_count(@selections, event_race.id)}/{length(runners)} sel.
                </span>
              </div>

              <%!-- Runners --%>
              <div class="space-y-1">
                <div
                  :if={runners == []}
                  class="text-sm text-base-content/40 text-center py-4"
                >
                  Sin datos de participantes aún.
                </div>
                <div
                  :for={runner <- runners}
                  class={[
                    "flex items-center justify-between p-2 rounded-lg cursor-pointer transition-colors select-none",
                    if(selected?(@selections, event_race.id, runner.id),
                      do: "bg-primary/10 border border-primary",
                      else: "bg-base-200 hover:bg-base-300"
                    )
                  ]}
                  phx-click="toggle_runner"
                  phx-value-race_id={event_race.id}
                  phx-value-runner_id={runner.id}
                >
                  <div class="flex items-center gap-3">
                    <span class="w-6 h-6 rounded-full bg-base-300 flex items-center justify-center text-xs font-bold shrink-0">
                      {runner.program_number}
                    </span>
                    <div>
                      <span class="font-medium">{runner.horse.name}</span>
                      <span :if={runner.jockey} class="text-xs text-base-content/60 ml-2">
                        {runner.jockey.name}
                      </span>
                    </div>
                  </div>
                  <div class="flex items-center gap-2 shrink-0">
                    <span :if={runner.morning_line} class="badge badge-ghost badge-sm">
                      {runner.morning_line}
                    </span>
                    <div class={[
                      "w-5 h-5 rounded border-2 flex items-center justify-center shrink-0",
                      if(selected?(@selections, event_race.id, runner.id),
                        do: "bg-primary border-primary",
                        else: "border-base-content/30"
                      )
                    ]}>
                      <.icon
                        :if={selected?(@selections, event_race.id, runner.id)}
                        name="hero-check"
                        class="w-3 h-3 text-primary-content"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- HvH Matchups --%>
      <div :if={@matchups != []} class="mt-8">
        <h2 class="text-xl font-bold mb-4">Horse vs Horse</h2>
        <div class="grid gap-4">
          <div
            :for={matchup <- @matchups}
            class="card bg-base-100 border border-base-200 shadow"
          >
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-3">
                <h3 class="font-bold text-sm text-base-content/70">
                  {matchup.race.distance_raw || "—"}
                </h3>
                <span class={hvh_status_badge(matchup.status)}>
                  {hvh_status_label(matchup.status)}
                </span>
              </div>

              <div class="grid grid-cols-2 gap-3 mb-3">
                <%!-- Side A --%>
                <button
                  class={[
                    "btn btn-outline h-auto py-3 flex-col gap-1",
                    if(hvh_side_selected?(@hvh_selections, matchup.id, :a),
                      do: "btn-primary",
                      else: ""
                    )
                  ]}
                  phx-click="hvh_select_side"
                  phx-value-matchup_id={matchup.id}
                  phx-value-side="a"
                  disabled={matchup.status != :open}
                >
                  <span class="text-xs font-bold uppercase tracking-wider">Lado A</span>
                  <span
                    :for={side <- Enum.filter(matchup.hvh_matchup_sides, &(&1.side == :a))}
                    class="text-sm font-normal"
                  >
                    {side.runner.horse.name}
                  </span>
                </button>

                <%!-- Side B --%>
                <button
                  class={[
                    "btn btn-outline h-auto py-3 flex-col gap-1",
                    if(hvh_side_selected?(@hvh_selections, matchup.id, :b),
                      do: "btn-secondary",
                      else: ""
                    )
                  ]}
                  phx-click="hvh_select_side"
                  phx-value-matchup_id={matchup.id}
                  phx-value-side="b"
                  disabled={matchup.status != :open}
                >
                  <span class="text-xs font-bold uppercase tracking-wider">Lado B</span>
                  <span
                    :for={side <- Enum.filter(matchup.hvh_matchup_sides, &(&1.side == :b))}
                    class="text-sm font-normal"
                  >
                    {side.runner.horse.name}
                  </span>
                </button>
              </div>

              <div
                :if={hvh_any_side?(@hvh_selections, matchup.id)}
                class="flex items-center gap-2"
              >
                <div class="flex-1">
                  <input
                    type="number"
                    class="input input-bordered input-sm w-full"
                    placeholder="Monto"
                    min="1"
                    value={hvh_amount(@hvh_selections, matchup.id)}
                    phx-change="hvh_set_amount"
                    phx-value-matchup_id={matchup.id}
                    name="amount"
                  />
                </div>
                <div class="text-xs text-base-content/60 shrink-0">
                  × {format_decimal(@event.game_config.prize_multiplier || Decimal.new("1.80"))}
                </div>
                <button
                  class="btn btn-sm btn-accent shrink-0"
                  phx-click="place_hvh_bet"
                  phx-value-matchup_id={matchup.id}
                >
                  Apostar
                </button>
              </div>

              <div class="flex gap-4 mt-2 text-xs text-base-content/50">
                <span>Lado A: ${format_decimal(matchup.total_side_a)}</span>
                <span>Lado B: ${format_decimal(matchup.total_side_b)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Bottom bar --%>
      <div class="fixed bottom-0 left-0 right-0 bg-base-100 border-t border-base-200 shadow-2xl z-10">
        <div class="max-w-3xl mx-auto flex items-center justify-between gap-3 p-4">
          <div class="text-center">
            <div class="text-xs text-base-content/60">Combinaciones</div>
            <div class="text-xl font-bold">{@combination_count}</div>
          </div>
          <div class="text-center">
            <div class="text-xs text-base-content/60">Valor</div>
            <div class="text-xl font-bold">${format_decimal(@event.game_config.ticket_value)}</div>
          </div>
          <div class="text-center">
            <div class="text-xs text-base-content/60">Total</div>
            <div class="text-xl font-bold text-primary">${format_decimal(@total_paid)}</div>
          </div>
          <button
            class="btn btn-primary btn-lg"
            phx-click="show_confirm"
            disabled={not @can_submit or @event.status != :open}
          >
            Apostar
          </button>
        </div>
      </div>

      <%!-- Confirmation modal --%>
      <div :if={@show_confirm} class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">Confirmar ticket</h3>

          <div class="space-y-2 mb-4">
            <div
              :for={{event_race, runners} <- @races_with_runners}
              :if={selected_count(@selections, event_race.id) > 0}
              class="flex justify-between text-sm"
            >
              <span class="text-base-content/60">Carrera {event_race.race_order}</span>
              <span class="font-medium">
                {selected_runner_names(@selections, event_race.id, runners)}
              </span>
            </div>
          </div>

          <div class="divider my-2"></div>

          <div class="space-y-1 text-sm mb-4">
            <div class="flex justify-between">
              <span>Combinaciones</span>
              <span class="font-bold">{@combination_count}</span>
            </div>
            <div class="flex justify-between">
              <span>Total a pagar</span>
              <span class="font-bold text-primary">${format_decimal(@total_paid)}</span>
            </div>
            <div class="flex justify-between text-base-content/60">
              <span>Saldo actual</span>
              <span>${format_decimal(@current_scope.user.balance)}</span>
            </div>
            <div class="flex justify-between text-base-content/60">
              <span>Saldo después</span>
              <span>${format_decimal(Decimal.sub(@current_scope.user.balance, @total_paid))}</span>
            </div>
          </div>

          <div class="modal-action">
            <button class="btn" phx-click="hide_confirm" disabled={@placing}>
              Cancelar
            </button>
            <button class="btn btn-primary" phx-click="place_ticket" disabled={@placing}>
              {if @placing, do: "Procesando...", else: "Confirmar"}
            </button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="hide_confirm"></div>
      </div>
      <%!-- Drawer overlay --%>
      <div
        :if={@show_my_tickets}
        class="fixed inset-0 bg-black/50 z-20"
        phx-click="close_my_tickets"
      >
      </div>

      <%!-- Drawer panel --%>
      <div
        :if={@show_my_tickets}
        class="fixed top-0 right-0 h-full w-full max-w-sm bg-base-100 shadow-2xl z-30 flex flex-col"
      >
        <%!-- Drawer header --%>
        <div class="flex items-center justify-between p-4 border-b border-base-200">
          <h2 class="font-bold text-lg">Mis tickets — {@event.name}</h2>
          <button phx-click="close_my_tickets" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <%!-- Drawer content --%>
        <div class="flex-1 overflow-y-auto p-4 space-y-6">
          <%!-- Polla tickets --%>
          <div>
            <h3 class="font-semibold text-sm text-base-content/60 uppercase tracking-wide mb-3">
              La Polla Hípica ({length(@my_polla_tickets)})
            </h3>

            <div :if={@my_polla_tickets == []} class="text-sm text-base-content/40 text-center py-4">
              Sin tickets en este evento.
            </div>

            <div class="space-y-3">
              <div
                :for={ticket <- @my_polla_tickets}
                class="card bg-base-200 shadow-sm"
              >
                <div class="card-body p-3">
                  <div class="flex items-center justify-between mb-2">
                    <span class="font-mono text-xs text-base-content/50">
                      #{String.slice(ticket.id, 0, 8)}
                    </span>
                    <span class={ticket_badge(ticket.status)}>
                      {ticket_label(ticket.status)}
                    </span>
                  </div>
                  <div class="flex justify-between text-sm mb-2">
                    <span class="text-base-content/60">{ticket.combination_count} combinaciones</span>
                    <span class="font-medium">${format_decimal(ticket.total_paid)}</span>
                  </div>
                  <%!-- Selecciones por carrera --%>
                  <div class="space-y-1">
                    <div
                      :for={
                        sel <- Enum.sort_by(ticket.polla_selections, & &1.game_event_race.race_order)
                      }
                      class="flex items-center justify-between text-xs"
                    >
                      <span class="text-base-content/50">
                        C{sel.game_event_race.race_order}
                      </span>
                      <span class={[
                        "font-medium",
                        if(sel.was_replaced, do: "line-through text-base-content/40", else: "")
                      ]}>
                        {sel.runner.horse.name}
                      </span>
                      <span :if={sel.points_earned > 0} class="text-success text-xs">
                        +{sel.points_earned}pts
                      </span>
                    </div>
                  </div>
                  <div
                    :if={ticket.total_points}
                    class="flex justify-between text-xs mt-2 pt-2 border-t border-base-300"
                  >
                    <span class="text-base-content/60">Puntos totales</span>
                    <span class="font-bold">{ticket.total_points}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- HvH bets --%>
          <div :if={@matchups != []}>
            <h3 class="font-semibold text-sm text-base-content/60 uppercase tracking-wide mb-3">
              Horse vs Horse ({length(@my_hvh_bets)})
            </h3>

            <div :if={@my_hvh_bets == []} class="text-sm text-base-content/40 text-center py-4">
              Sin apuestas HvH en este evento.
            </div>

            <div class="space-y-3">
              <div
                :for={bet <- @my_hvh_bets}
                class="card bg-base-200 shadow-sm"
              >
                <div class="card-body p-3">
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-xs text-base-content/50">
                      {bet.hvh_matchup.race.distance_raw || "—"}
                    </span>
                    <span class={hvh_bet_badge(bet.status)}>
                      {hvh_bet_label(bet.status)}
                    </span>
                  </div>
                  <div class="flex items-center justify-between text-sm">
                    <span class={
                      if bet.side_chosen == :a,
                        do: "badge badge-primary badge-sm",
                        else: "badge badge-secondary badge-sm"
                    }>
                      {if bet.side_chosen == :a, do: "Lado A", else: "Lado B"}
                    </span>
                    <span class="font-medium">${format_decimal(bet.amount)}</span>
                    <span class="text-base-content/60 text-xs">
                      → ${format_decimal(bet.potential_payout)}
                    </span>
                  </div>
                  <div :if={bet.status == :won} class="text-success font-bold text-sm mt-1">
                    Cobrado: ${format_decimal(bet.actual_payout)}
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

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp compute_totals(selections, %{races_with_runners: races, event: event}) do
    race_ids = Enum.map(races, fn {ger, _} -> ger.id end)
    ticket_value = event.game_config.ticket_value || Decimal.new("1.00")

    all_complete =
      Enum.all?(race_ids, fn id ->
        MapSet.size(Map.get(selections, id, MapSet.new())) > 0
      end)

    count =
      if all_complete do
        Enum.reduce(race_ids, 1, fn id, acc ->
          acc * MapSet.size(Map.get(selections, id, MapSet.new()))
        end)
      else
        0
      end

    total =
      if count > 0,
        do: Decimal.mult(Decimal.new(count), ticket_value),
        else: Decimal.new("0.00")

    {count, total, all_complete}
  end

  defp selected?(_selections, _race_id, nil), do: false

  defp selected?(selections, race_id, runner_id) do
    race_id
    |> then(&Map.get(selections, to_string(&1), MapSet.new()))
    |> MapSet.member?(to_string(runner_id))
  end

  defp selected_count(selections, race_id) do
    selections
    |> Map.get(to_string(race_id), MapSet.new())
    |> MapSet.size()
  end

  defp race_complete?(selections, race_id, runners) do
    selected_count(selections, race_id) > 0 and length(runners) > 0
  end

  defp selected_runner_names(selections, race_id, runners) do
    selected_ids = Map.get(selections, to_string(race_id), MapSet.new())

    runners
    |> Enum.filter(fn r -> MapSet.member?(selected_ids, to_string(r.id)) end)
    |> Enum.map_join(", ", fn r -> r.horse.name end)
  end

  defp time_remaining(nil), do: nil

  defp time_remaining(closes_at) do
    max(0, DateTime.diff(closes_at, DateTime.utc_now(), :second))
  end

  defp format_countdown(nil), do: "—"

  defp format_countdown(0), do: "Cerrado"

  defp format_countdown(seconds) do
    h = div(seconds, 3600)
    m = seconds |> rem(3600) |> div(60)
    s = rem(seconds, 60)

    if h > 0 do
      :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> IO.iodata_to_binary()
    else
      :io_lib.format("~2..0B:~2..0B", [m, s]) |> IO.iodata_to_binary()
    end
  end

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(d), do: Decimal.round(d, 2) |> Decimal.to_string()

  defp hvh_side_selected?(hvh_selections, matchup_id, side) do
    hvh_selections |> Map.get(to_string(matchup_id), %{}) |> Map.get(:side) == side
  end

  defp hvh_any_side?(hvh_selections, matchup_id) do
    hvh_selections |> Map.get(to_string(matchup_id), %{}) |> Map.get(:side) |> is_atom() and
      not is_nil(hvh_selections |> Map.get(to_string(matchup_id), %{}) |> Map.get(:side))
  end

  defp hvh_amount(hvh_selections, matchup_id) do
    hvh_selections |> Map.get(to_string(matchup_id), %{}) |> Map.get(:amount, "")
  end

  defp hvh_status_badge(:open), do: "badge badge-success badge-sm"
  defp hvh_status_badge(:closed), do: "badge badge-warning badge-sm"
  defp hvh_status_badge(:finished), do: "badge badge-neutral badge-sm"
  defp hvh_status_badge(:void), do: "badge badge-error badge-sm"
  defp hvh_status_badge(_), do: "badge badge-ghost badge-sm"

  defp hvh_status_label(:open), do: "Abierto"
  defp hvh_status_label(:closed), do: "Cerrado"
  defp hvh_status_label(:finished), do: "Terminado"
  defp hvh_status_label(:void), do: "Nulo"
  defp hvh_status_label(_), do: "—"

  defp ticket_badge(:active), do: "badge badge-info badge-sm"
  defp ticket_badge(:winner), do: "badge badge-success badge-sm"
  defp ticket_badge(:loser), do: "badge badge-neutral badge-sm"
  defp ticket_badge(:refunded), do: "badge badge-warning badge-sm"
  defp ticket_badge(_), do: "badge badge-ghost badge-sm"

  defp ticket_label(:active), do: "Activo"
  defp ticket_label(:winner), do: "Ganador"
  defp ticket_label(:loser), do: "Perdedor"
  defp ticket_label(:refunded), do: "Reembolsado"
  defp ticket_label(_), do: "—"

  defp hvh_bet_badge(:pending), do: "badge badge-info badge-sm"
  defp hvh_bet_badge(:won), do: "badge badge-success badge-sm"
  defp hvh_bet_badge(:lost), do: "badge badge-neutral badge-sm"
  defp hvh_bet_badge(:void), do: "badge badge-warning badge-sm"
  defp hvh_bet_badge(:refunded), do: "badge badge-warning badge-sm"
  defp hvh_bet_badge(_), do: "badge badge-ghost badge-sm"

  defp hvh_bet_label(:pending), do: "Pendiente"
  defp hvh_bet_label(:won), do: "Ganado"
  defp hvh_bet_label(:lost), do: "Perdido"
  defp hvh_bet_label(:void), do: "Nulo"
  defp hvh_bet_label(:refunded), do: "Reembolsado"
  defp hvh_bet_label(_), do: "—"

  defp event_status_badge(:open), do: "badge badge-success"
  defp event_status_badge(:closed), do: "badge badge-warning"
  defp event_status_badge(:finished), do: "badge badge-neutral"
  defp event_status_badge(:canceled), do: "badge badge-error"
  defp event_status_badge(_), do: "badge badge-ghost"

  defp status_label(:open), do: "Abierto"
  defp status_label(:closed), do: "Cerrado"
  defp status_label(:finished), do: "Finalizado"
  defp status_label(:canceled), do: "Cancelado"
  defp status_label(:processing), do: "Procesando"
  defp status_label(_), do: "Borrador"
end
