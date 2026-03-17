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
     |> assign(:expanded_combo_ids, MapSet.new())
     |> assign(:selected_tab, :polla)
     |> assign(
       :my_polla_tickets,
       Betting.list_polla_tickets_for_user_and_event(user_id, event.id)
     )
     |> assign(:my_hvh_bets, Betting.list_hvh_bets_for_user_and_event(user_id, event.id))
     |> assign(
       :leaderboard_rows,
       if(event.status == :finished, do: Betting.list_leaderboard_rows(event.id), else: [])
     )}
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

  def handle_event("switch_game_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, String.to_existing_atom(tab))}
  end

  def handle_event("open_my_tickets", _, socket) do
    {:noreply, assign(socket, :show_my_tickets, true)}
  end

  def handle_event("close_my_tickets", _, socket) do
    {:noreply, assign(socket, :show_my_tickets, false)}
  end

  def handle_event("toggle_combo_detail", %{"combo_id" => combo_id}, socket) do
    ids = socket.assigns.expanded_combo_ids

    new_ids =
      if MapSet.member?(ids, combo_id) do
        MapSet.delete(ids, combo_id)
      else
        MapSet.put(ids, combo_id)
      end

    {:noreply, assign(socket, :expanded_combo_ids, new_ids)}
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
      <div class="pb-28">
        <%!-- Header --%>
        <div class="flex items-center justify-between gap-2 mb-2">
          <div class="min-w-0">
            <h1 class="text-xl font-bold leading-tight truncate">{@event.name}</h1>
            <p class="text-xs text-base-content/60">{@event.course.full_name}</p>
          </div>
          <div class="text-right shrink-0 flex items-center gap-3">
            <span class={event_status_badge(@event.status)}>{status_label(@event.status)}</span>
            <div :if={@event.status == :open}>
              <div class="text-lg font-mono font-bold tabular-nums leading-none text-warning">
                {format_countdown(@time_remaining)}
              </div>
              <p
                :if={@event.status == :open and (@time_remaining || 0) > 0}
                class="text-xs text-warning/60 text-right"
              >
                hasta cerrar
              </p>
            </div>
          </div>
        </div>

        <%= if @event.status == :finished do %>
          <%!-- Vista Resultados (evento finalizado) --%>
          <section class="mb-4 p-3 rounded-lg bg-base-200">
            <div class="flex flex-wrap gap-4 text-sm">
              <span>Bote: <strong>${format_decimal(@event.total_pool)}</strong></span>
              <span>
                Valor base: <strong>${format_decimal(@event.game_config.ticket_value)}</strong>
              </span>
              <span>
                Combinaciones: <strong>{leaderboard_total_combos(@leaderboard_rows)}</strong>
              </span>
            </div>
          </section>
          <section class="mb-4">
            <h2 class="text-lg font-semibold mb-2">Resultados</h2>
            <div class="overflow-x-auto rounded-lg border border-base-200">
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
          <div class="flex justify-end">
            <button phx-click="open_my_tickets" class="btn btn-outline btn-sm gap-1">
              <.icon name="hero-ticket" class="size-4" /> Mis tickets
              <span
                :if={length(@my_polla_tickets) + length(@my_hvh_bets) > 0}
                class="badge badge-sm badge-primary"
              >
                {length(@my_polla_tickets) + length(@my_hvh_bets)}
              </span>
            </button>
          </div>
        <% else %>
          <div>
            <%!-- Game tabs --%>
            <div role="tablist" class="tabs tabs-bordered mb-2">
              <button
                role="tab"
                class={[
                  "tab tab-sm",
                  if(@selected_tab == :polla, do: "tab-active font-semibold", else: "")
                ]}
                phx-click="switch_game_tab"
                phx-value-tab="polla"
              >
                La Polla Hípica
              </button>
              <button
                :if={@matchups != []}
                role="tab"
                class={[
                  "tab tab-sm",
                  if(@selected_tab == :hvh, do: "tab-active font-semibold", else: "")
                ]}
                phx-click="switch_game_tab"
                phx-value-tab="hvh"
              >
                Horse vs Horse <span class="badge badge-sm ml-1">{length(@matchups)}</span>
              </button>
            </div>

            <%!-- ══ POLLA TAB ══ --%>
            <div :if={@selected_tab == :polla}>
              <%!-- Info strip --%>
              <div class="flex flex-wrap gap-3 mb-2 text-xs text-base-content/60">
                <span>
                  Ticket:
                  <strong class="text-base-content">
                    ${format_decimal(@event.game_config.ticket_value)}
                  </strong>
                </span>
                <span>
                  Máx/carrera:
                  <strong class="text-base-content">
                    {@event.game_config.max_horses_per_race || 3}
                  </strong>
                </span>
                <span>
                  Bote:
                  <strong class="text-base-content">${format_decimal(@event.total_pool)}</strong>
                </span>
              </div>

              <%!-- Mis tickets button --%>
              <div class="flex justify-end mb-3">
                <button
                  phx-click="open_my_tickets"
                  class={[
                    "btn btn-sm gap-2 shadow-sm transition-all duration-200",
                    if(length(@my_polla_tickets) + length(@my_hvh_bets) > 0,
                      do: "btn-primary hover:shadow-md",
                      else: "btn-outline hover:bg-base-200"
                    )
                  ]}
                >
                  <.icon name="hero-ticket" class="size-5" />
                  <span>Mis tickets</span>
                  <span
                    :if={length(@my_polla_tickets) + length(@my_hvh_bets) > 0}
                    class="badge badge-sm badge-primary border-0 min-w-[1.25rem]"
                  >
                    {length(@my_polla_tickets) + length(@my_hvh_bets)}
                  </span>
                </button>
              </div>

              <%!-- Todas las carreras en la misma vista: una fila por carrera, números alineados horizontalmente --%>
              <div class="space-y-4">
                <%= for {{event_race, runners}, idx} <- Enum.with_index(@races_with_runners) do %>
                  <div class="rounded-xl border border-base-200 bg-base-100 px-4 py-4">
                    <div class="flex items-center justify-between mb-3">
                      <h2 class="text-sm font-bold tracking-wide text-primary uppercase">
                        {idx + 1}ª Válida
                        <span class="text-base-content/40 font-normal normal-case ml-1">
                          — Carrera {event_race.race_order}
                        </span>
                      </h2>
                      <span class={[
                        "badge badge-sm font-semibold",
                        if(race_complete?(@selections, event_race.id, runners),
                          do: "badge-success",
                          else: "badge-ghost"
                        )
                      ]}>
                        {selected_count(@selections, event_race.id)}/{if(runners == [],
                          do: 0,
                          else: length(runners)
                        )}
                      </span>
                    </div>
                    <div
                      :if={runners == []}
                      class="text-sm text-base-content/40 py-4 text-center"
                    >
                      Sin datos de participantes aún.
                    </div>
                    <div
                      :if={runners != []}
                      class="flex flex-wrap gap-2 pt-1"
                    >
                      <button
                        :for={runner <- runners}
                        type="button"
                        class={[
                          "btn btn-square btn-sm rounded-xl font-bold text-sm transition-all duration-150",
                          if(selected?(@selections, event_race.id, runner.id),
                            do: "btn-primary",
                            else: "btn-neutral hover:btn-ghost"
                          )
                        ]}
                        phx-click="toggle_runner"
                        phx-value-race_id={event_race.id}
                        phx-value-runner_id={runner.id}
                      >
                        {runner.program_number}
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- ══ HVH TAB ══ --%>
            <div :if={@selected_tab == :hvh}>
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
          </div>

          <%!-- Bottom bar (solo Polla) --%>
          <div
            :if={@selected_tab == :polla}
            class="fixed bottom-0 left-0 right-0 bg-base-100 border-t border-base-200 shadow-2xl z-10"
          >
            <div class="max-w-3xl mx-auto flex items-center justify-between gap-3 p-4">
              <div class="text-center">
                <div class="text-xs text-base-content/60">Combinaciones</div>
                <div class="text-xl font-bold">{@combination_count}</div>
              </div>
              <div class="text-center">
                <div class="text-xs text-base-content/60">Valor</div>
                <div class="text-xl font-bold">
                  ${format_decimal(@event.game_config.ticket_value)}
                </div>
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
                  <span>
                    ${format_decimal(Decimal.sub(@current_scope.user.balance, @total_paid))}
                  </span>
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
        <% end %>
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
        class="fixed top-0 right-0 h-full w-full max-w-sm bg-base-100 shadow-2xl z-30 flex flex-col pt-16"
      >
        <%!-- Drawer header --%>
        <div class="flex items-center justify-between p-4 border-b border-base-200">
          <h2 class="font-bold text-lg">Mis tickets — {@event.name}</h2>
          <button phx-click="close_my_tickets" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <%!-- Drawer balance --%>
        <div class="flex items-center justify-between px-4 py-2 bg-base-200/60 border-b border-base-200">
          <span class="text-xs text-base-content/50">Saldo disponible</span>
          <span class="font-mono font-bold text-sm text-success">
            ${format_decimal(@current_scope.user.balance)}
          </span>
        </div>

        <%!-- Drawer content --%>
        <div class="flex-1 overflow-y-auto p-4 space-y-6">
          <%!-- Polla tickets --%>
          <div>
            <h3 class="font-semibold text-sm text-base-content/60 uppercase tracking-wide pt-2 mb-3">
              La Polla Hípica ({length(@my_polla_tickets)})
            </h3>

            <div :if={@my_polla_tickets == []} class="text-sm text-base-content/40 text-center py-4">
              Sin tickets en este evento.
            </div>

            <div class="space-y-4">
              <div :for={ticket <- @my_polla_tickets} class="space-y-2">
                <div class="flex items-center justify-between text-xs text-base-content/60">
                  <span class="font-mono">#{String.slice(ticket.id, 0, 8)}</span>
                  <span class={ticket_badge(ticket.status)}>{ticket_label(ticket.status)}</span>
                </div>
                <div class="flex justify-between text-sm mb-1">
                  <span>{ticket.combination_count} combinaciones</span>
                  <span class="font-medium">${format_decimal(ticket.total_paid)}</span>
                </div>
                <% points_lookup = selection_points_lookup(ticket) %>
                <div class="space-y-2">
                  <div
                    :for={combo <- combo_cards_for_ticket(ticket)}
                    class="card bg-base-200 shadow-sm border border-base-300"
                  >
                    <div
                      class="card-body p-3 cursor-pointer"
                      phx-click="toggle_combo_detail"
                      phx-value-combo_id={combo.id}
                    >
                      <div class="flex items-center justify-between gap-2">
                        <span class="font-mono font-semibold text-sm">
                          {combo_string(combo)}
                        </span>
                        <div class="flex items-center gap-2 shrink-0">
                          <span class="badge badge-ghost badge-sm">
                            {combo.total_points} pts
                          </span>
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
                      <%!-- Detalle por válida --%>
                      <div
                        :if={MapSet.member?(@expanded_combo_ids, combo.id)}
                        class="mt-3 pt-3 border-t border-base-300"
                      >
                        <p class="text-xs text-base-content/50 uppercase tracking-wide mb-2">
                          Detalle por válida
                        </p>
                        <div class="grid grid-cols-3 gap-x-4 gap-y-1 text-xs">
                          <div
                            :for={cs <- combo_selections_sorted(combo)}
                            class="flex justify-between"
                          >
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
    |> Enum.sort_by(& &1.program_number)
    |> Enum.map_join(", ", fn r -> to_string(r.program_number) end)
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

  defp selection_points_lookup(ticket) do
    ticket.polla_selections
    |> Map.new(fn s -> {{s.game_event_race_id, s.runner_id}, s.points_earned} end)
  end

  defp combo_cards_for_ticket(ticket) do
    ticket.polla_combinations
    |> Enum.sort_by(& &1.combination_index)
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

  defp leaderboard_num_races([]), do: 0
  defp leaderboard_num_races([row | _]), do: length(row.races)

  defp leaderboard_total_combos(rows), do: length(rows)
end
