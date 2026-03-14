defmodule BetPlace.Betting.Settlement do
  @moduledoc """
  Handles race scoring, prize settlement, non-runner replacements, and cancellations.

  Called by SyncService after race detail syncs. All operations are idempotent.
  """

  require Logger
  import Ecto.Query

  alias BetPlace.Repo
  alias BetPlace.Games.{GameEvent, GameEventRace}
  alias BetPlace.Betting.{PollaTicket, PollaSelection, PollaCombination, HvhMatchup, HvhBet}
  alias BetPlace.Accounts.User
  alias BetPlace.Finance.Transaction
  alias BetPlace.Racing
  alias BetPlace.Racing.RunnerReplacement

  # ── Score Race ────────────────────────────────────────────────────────────

  @doc """
  Scores all polla_selections for a finished game_event_race.
  Marks the race as finished, then checks if the whole event can be settled.
  """
  def score_race(game_event_race_id) do
    Logger.info("Settlement: scoring game_event_race #{game_event_race_id}")

    ger = Repo.get!(GameEventRace, game_event_race_id)

    PollaSelection
    |> where([s], s.game_event_race_id == ^game_event_race_id)
    |> preload(:effective_runner)
    |> Repo.all()
    |> Enum.each(fn selection ->
      pts = points_for_position(selection.effective_runner && selection.effective_runner.position)
      selection |> PollaSelection.score_changeset(pts) |> Repo.update!()
    end)

    ger |> GameEventRace.status_changeset(:finished) |> Repo.update!()

    maybe_settle_event(ger.game_event_id)
    :ok
  end

  # ── Prize Settlement ──────────────────────────────────────────────────────

  @doc """
  Computes final combination scores, identifies winner(s), and distributes prizes.
  Called automatically when all races in an event are finished.
  """
  def settle_game_event(game_event_id) do
    Logger.info("Settlement: settling game event #{game_event_id}")

    event =
      GameEvent
      |> preload([:game_config, :game_event_races])
      |> Repo.get!(game_event_id)

    event |> GameEvent.status_changeset(:processing) |> Repo.update!()

    ordered_races =
      event.game_event_races
      |> Enum.filter(&(&1.status == :finished))
      |> Enum.sort_by(& &1.race_order)

    tickets =
      PollaTicket
      |> where([t], t.game_event_id == ^game_event_id and t.status == :active)
      |> Repo.all()

    # Score all combinations for all tickets
    Enum.each(tickets, fn ticket ->
      score_ticket_combinations(ticket, ordered_races)
    end)

    # Find max points across all combinations for this event
    max_points =
      PollaCombination
      |> join(:inner, [pc], t in PollaTicket, on: pc.polla_ticket_id == t.id)
      |> where([pc, t], t.game_event_id == ^game_event_id)
      |> Repo.aggregate(:max, :total_points) || 0

    house_cut = event.game_config.house_cut_pct || Decimal.new("0.10")
    prize_pool = Decimal.mult(event.total_pool, Decimal.sub(Decimal.new("1"), house_cut))
    house_amount = Decimal.sub(event.total_pool, prize_pool)

    winning_combos =
      PollaCombination
      |> join(:inner, [pc], t in PollaTicket, on: pc.polla_ticket_id == t.id)
      |> where([pc, t], t.game_event_id == ^game_event_id and pc.total_points == ^max_points)
      |> Repo.all()

    winner_count = length(winning_combos)

    individual_prize =
      if winner_count > 0,
        do: Decimal.div(prize_pool, Decimal.new(winner_count)),
        else: Decimal.new("0")

    winning_ticket_ids = Enum.map(winning_combos, & &1.polla_ticket_id) |> Enum.uniq()

    Enum.each(winning_combos, fn combo ->
      ticket = Repo.get!(PollaTicket, combo.polla_ticket_id)
      user = Repo.get!(User, ticket.user_id)
      new_balance = Decimal.add(user.balance, individual_prize)

      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :combo,
        PollaCombination.result_changeset(combo, %{
          prize_amount: individual_prize,
          is_winner: true
        })
      )
      |> Ecto.Multi.update(
        :ticket,
        PollaTicket.result_changeset(ticket, %{total_points: max_points, status: :winner})
      )
      |> Ecto.Multi.update(:credit_user, User.balance_changeset(user, %{balance: new_balance}))
      |> Ecto.Multi.insert(
        :transaction,
        Transaction.changeset(%Transaction{}, %{
          user_id: user.id,
          type: :payout,
          direction: :credit,
          amount: individual_prize,
          balance_before: user.balance,
          balance_after: new_balance,
          reference_type: "polla_ticket",
          reference_id: ticket.id,
          status: :completed
        })
      )
      |> Repo.transaction()
      |> case do
        {:ok, _} ->
          Phoenix.PubSub.broadcast(
            BetPlace.PubSub,
            "user:#{user.id}",
            {:balance_updated, new_balance}
          )

        {:error, step, reason, _} ->
          Logger.error(
            "Settlement: payout failed for ticket #{ticket.id} at #{step}: #{inspect(reason)}"
          )
      end
    end)

    # Mark losing tickets
    Repo.update_all(
      from(t in PollaTicket,
        where: t.game_event_id == ^game_event_id and t.id not in ^winning_ticket_ids
      ),
      set: [status: :loser]
    )

    event
    |> GameEvent.pool_changeset(%{prize_pool: prize_pool, house_amount: house_amount})
    |> Repo.update!()

    event |> GameEvent.status_changeset(:finished) |> Repo.update!()

    Phoenix.PubSub.broadcast(
      BetPlace.PubSub,
      "game_event:#{game_event_id}",
      {:game_event_settled, game_event_id}
    )

    Logger.info(
      "Settlement: event #{game_event_id} settled. Winners: #{winner_count}, Prize pool: #{prize_pool}"
    )

    :ok
  end

  # ── Non-runner Handling ───────────────────────────────────────────────────

  @doc """
  Processes a withdrawn runner. Finds the replacement (next program number),
  inserts a RunnerReplacement record, and updates affected polla_selections.
  Idempotent — safe to call multiple times.
  """
  def handle_non_runner(race_id, original_program_number) do
    Logger.info("Settlement: non-runner ##{original_program_number} in race #{race_id}")

    original = Racing.get_runner_by_race_and_program_number(race_id, original_program_number)

    replacement = Racing.find_next_active_runner(race_id, original_program_number)

    cond do
      is_nil(original) ->
        Logger.warning(
          "Settlement: original runner ##{original_program_number} not found in race #{race_id}"
        )

      is_nil(replacement) ->
        Logger.warning(
          "Settlement: no replacement for runner ##{original_program_number} in race #{race_id}"
        )

      already_replaced?(original.id) ->
        Logger.info("Settlement: runner #{original.id} already replaced, skipping")

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Racing.create_runner_replacement(%{
          race_id: race_id,
          original_runner_id: original.id,
          replacement_runner_id: replacement.id,
          reason: :non_runner,
          replaced_at: now
        })

        race_event_ids =
          GameEventRace
          |> where([ger], ger.race_id == ^race_id)
          |> select([ger], {ger.id, ger.game_event_id})
          |> Repo.all()

        Repo.update_all(
          from(s in PollaSelection,
            where:
              s.runner_id == ^original.id and
                s.game_event_race_id in ^Enum.map(race_event_ids, &elem(&1, 0))
          ),
          set: [effective_runner_id: replacement.id, was_replaced: true]
        )

        Enum.each(race_event_ids, fn {_ger_id, game_event_id} ->
          Phoenix.PubSub.broadcast(
            BetPlace.PubSub,
            "game_event:#{game_event_id}",
            {:non_runner, original.id, replacement.id}
          )
        end)

        Logger.info("Settlement: replaced #{original.id} → #{replacement.id}")
    end

    :ok
  end

  # ── HvH Matchup Resolution ───────────────────────────────────────────────

  @doc """
  Resolves an HvH matchup after the race finishes.
  Compares the best position (lowest) of each side within top 5.
  """
  def resolve_hvh_matchup(matchup_id) do
    matchup =
      HvhMatchup
      |> preload(hvh_matchup_sides: :runner)
      |> Repo.get!(matchup_id)

    if matchup.status in [:finished, :void] do
      Logger.info("Settlement HvH: matchup #{matchup_id} already resolved, skipping")
      :ok
    else
      sides_a = Enum.filter(matchup.hvh_matchup_sides, &(&1.side == :a))
      sides_b = Enum.filter(matchup.hvh_matchup_sides, &(&1.side == :b))

      has_non_runner =
        Enum.any?(matchup.hvh_matchup_sides, fn s -> s.runner && s.runner.non_runner end)

      if has_non_runner do
        void_hvh_matchup(matchup_id, "Non-runner in matchup")
      else
        best_a = best_top5_position(sides_a)
        best_b = best_top5_position(sides_b)

        cond do
          is_nil(best_a) and is_nil(best_b) ->
            void_hvh_matchup(matchup_id, "No runner finished in top 5")

          is_nil(best_a) ->
            settle_hvh_winner(matchup, :side_b)

          is_nil(best_b) ->
            settle_hvh_winner(matchup, :side_a)

          best_a < best_b ->
            settle_hvh_winner(matchup, :side_a)

          best_b < best_a ->
            settle_hvh_winner(matchup, :side_b)

          true ->
            void_hvh_matchup(matchup_id, "Tie in position")
        end
      end
    end
  end

  @doc """
  Voids an HvH matchup and refunds all pending bets.
  """
  def void_hvh_matchup(matchup_id, reason) do
    Logger.info("Settlement HvH: voiding matchup #{matchup_id} — #{reason}")
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    matchup = Repo.get!(HvhMatchup, matchup_id)

    matchup
    |> HvhMatchup.result_changeset(%{
      status: :void,
      result_side: :void,
      void_reason: reason,
      resolved_at: now
    })
    |> Repo.update!()

    bets =
      HvhBet
      |> where([b], b.hvh_matchup_id == ^matchup_id and b.status == :pending)
      |> Repo.all()

    Enum.each(bets, fn bet ->
      refund_hvh_bet(bet)
    end)

    Phoenix.PubSub.broadcast(
      BetPlace.PubSub,
      "game_event:#{matchup.game_event_id}",
      {:hvh_matchup_voided, matchup_id}
    )

    Logger.info("Settlement HvH: voided matchup #{matchup_id}, refunded #{length(bets)} bets")
    :ok
  end

  @doc """
  Voids all open HvH matchups that include a specific non-runner.
  """
  def void_hvh_for_non_runner(race_id, runner_id) do
    matchup_ids =
      from(ms in BetPlace.Betting.HvhMatchupSide,
        join: m in HvhMatchup,
        on: ms.hvh_matchup_id == m.id,
        where:
          ms.runner_id == ^runner_id and m.race_id == ^race_id and m.status in [:open, :closed],
        select: m.id,
        distinct: true
      )
      |> Repo.all()

    Enum.each(matchup_ids, fn id ->
      void_hvh_matchup(id, "Non-runner withdrawal")
    end)
  end

  @doc """
  Voids all open HvH matchups for a canceled race.
  """
  def void_hvh_for_canceled_race(race_id) do
    matchup_ids =
      HvhMatchup
      |> where([m], m.race_id == ^race_id and m.status in [:open, :closed])
      |> select([m], m.id)
      |> Repo.all()

    Enum.each(matchup_ids, fn id ->
      void_hvh_matchup(id, "Race canceled")
    end)
  end

  # ── Canceled Race Handling ────────────────────────────────────────────────

  @doc """
  Handles a canceled race. Voids the whole game event and refunds all active polla tickets.
  Also voids all HvH matchups for the canceled race.
  """
  def handle_canceled_race(game_event_race_id) do
    Logger.info("Settlement: canceled race for game_event_race #{game_event_race_id}")

    ger = Repo.get!(GameEventRace, game_event_race_id)
    ger |> GameEventRace.status_changeset(:canceled) |> Repo.update!()

    void_hvh_for_canceled_race(ger.race_id)

    event = Repo.get!(GameEvent, ger.game_event_id)

    if event.status in [:open, :closed] do
      event |> GameEvent.status_changeset(:canceled) |> Repo.update!()
      refund_all_tickets(event)
    end

    :ok
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp maybe_settle_event(game_event_id) do
    event = Repo.get!(GameEvent, game_event_id)

    if event.status in [:canceled, :finished, :processing] do
      :skip
    else
      all_done =
        GameEventRace
        |> where([ger], ger.game_event_id == ^game_event_id)
        |> Repo.all()
        |> Enum.all?(&(&1.status in [:finished, :canceled]))

      if all_done, do: settle_game_event(game_event_id), else: :pending
    end
  end

  defp score_ticket_combinations(ticket, ordered_races) do
    selections =
      PollaSelection
      |> where([s], s.polla_ticket_id == ^ticket.id)
      |> Repo.all()

    selections_by_race =
      Enum.map(ordered_races, fn ger ->
        runner_ids =
          selections
          |> Enum.filter(&(&1.game_event_race_id == ger.id))
          |> Enum.map(& &1.runner_id)
          |> Enum.sort()

        {ger.id, runner_ids}
      end)

    points_lookup =
      Map.new(selections, fn s -> {{s.game_event_race_id, s.runner_id}, s.points_earned} end)

    runner_lists = Enum.map(selections_by_race, fn {_, ids} -> ids end)
    combinations = cartesian_product(runner_lists)
    race_ids = Enum.map(selections_by_race, fn {id, _} -> id end)

    combos =
      PollaCombination
      |> where([pc], pc.polla_ticket_id == ^ticket.id)
      |> order_by([pc], pc.combination_index)
      |> Repo.all()

    combinations
    |> Enum.with_index(0)
    |> Enum.each(fn {combo_runners, idx} ->
      combo = Enum.at(combos, idx)

      if combo do
        total_pts =
          combo_runners
          |> Enum.zip(race_ids)
          |> Enum.reduce(0, fn {runner_id, race_id}, acc ->
            acc + Map.get(points_lookup, {race_id, runner_id}, 0)
          end)

        combo
        |> PollaCombination.result_changeset(%{total_points: total_pts})
        |> Repo.update!()
      end
    end)
  end

  defp refund_all_tickets(event) do
    tickets =
      PollaTicket
      |> where([t], t.game_event_id == ^event.id and t.status == :active)
      |> Repo.all()

    Enum.each(tickets, fn ticket ->
      user = Repo.get!(User, ticket.user_id)
      new_balance = Decimal.add(user.balance, ticket.total_paid)

      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :ticket,
        PollaTicket.result_changeset(ticket, %{status: :refunded})
      )
      |> Ecto.Multi.update(:credit, User.balance_changeset(user, %{balance: new_balance}))
      |> Ecto.Multi.insert(
        :transaction,
        Transaction.changeset(%Transaction{}, %{
          user_id: user.id,
          type: :refund,
          direction: :credit,
          amount: ticket.total_paid,
          balance_before: user.balance,
          balance_after: new_balance,
          reference_type: "polla_ticket",
          reference_id: ticket.id,
          status: :completed
        })
      )
      |> Repo.transaction()
      |> case do
        {:ok, _} ->
          Phoenix.PubSub.broadcast(
            BetPlace.PubSub,
            "user:#{user.id}",
            {:balance_updated, new_balance}
          )

        {:error, step, reason, _} ->
          Logger.error(
            "Settlement: refund failed for ticket #{ticket.id} at #{step}: #{inspect(reason)}"
          )
      end
    end)

    Phoenix.PubSub.broadcast(
      BetPlace.PubSub,
      "game_event:#{event.id}",
      {:game_event_canceled, event.id}
    )

    Logger.info("Settlement: refunded #{length(tickets)} tickets for canceled event #{event.id}")
  end

  defp settle_hvh_winner(matchup, winning_side) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    matchup
    |> HvhMatchup.result_changeset(%{
      status: :finished,
      result_side: winning_side,
      resolved_at: now
    })
    |> Repo.update!()

    winning_side_atom = if winning_side == :side_a, do: :a, else: :b

    bets =
      HvhBet
      |> where([b], b.hvh_matchup_id == ^matchup.id and b.status == :pending)
      |> Repo.all()

    Enum.each(bets, fn bet ->
      if bet.side_chosen == winning_side_atom do
        pay_hvh_winner(bet)
      else
        bet
        |> HvhBet.result_changeset(%{status: :lost, actual_payout: Decimal.new("0")})
        |> Repo.update!()
      end
    end)

    Phoenix.PubSub.broadcast(
      BetPlace.PubSub,
      "game_event:#{matchup.game_event_id}",
      {:hvh_matchup_settled, matchup.id, winning_side}
    )

    Logger.info("Settlement HvH: matchup #{matchup.id} won by #{winning_side}")
    :ok
  end

  defp pay_hvh_winner(bet) do
    user = Repo.get!(User, bet.user_id)
    payout = bet.potential_payout
    new_balance = Decimal.add(user.balance, payout)

    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :bet,
      HvhBet.result_changeset(bet, %{status: :won, actual_payout: payout})
    )
    |> Ecto.Multi.update(:credit_user, User.balance_changeset(user, %{balance: new_balance}))
    |> Ecto.Multi.insert(
      :transaction,
      Transaction.changeset(%Transaction{}, %{
        user_id: user.id,
        type: :payout,
        direction: :credit,
        amount: payout,
        balance_before: user.balance,
        balance_after: new_balance,
        reference_type: "hvh_bet",
        reference_id: bet.id,
        status: :completed
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "user:#{user.id}",
          {:balance_updated, new_balance}
        )

      {:error, step, reason, _} ->
        Logger.error(
          "Settlement HvH: payout failed for bet #{bet.id} at #{step}: #{inspect(reason)}"
        )
    end
  end

  defp refund_hvh_bet(bet) do
    user = Repo.get!(User, bet.user_id)
    new_balance = Decimal.add(user.balance, bet.amount)

    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :bet,
      HvhBet.result_changeset(bet, %{status: :refunded, actual_payout: Decimal.new("0")})
    )
    |> Ecto.Multi.update(:credit_user, User.balance_changeset(user, %{balance: new_balance}))
    |> Ecto.Multi.insert(
      :transaction,
      Transaction.changeset(%Transaction{}, %{
        user_id: user.id,
        type: :refund,
        direction: :credit,
        amount: bet.amount,
        balance_before: user.balance,
        balance_after: new_balance,
        reference_type: "hvh_bet",
        reference_id: bet.id,
        status: :completed
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "user:#{user.id}",
          {:balance_updated, new_balance}
        )

      {:error, step, reason, _} ->
        Logger.error(
          "Settlement HvH: refund failed for bet #{bet.id} at #{step}: #{inspect(reason)}"
        )
    end
  end

  defp best_top5_position(sides) do
    sides
    |> Enum.map(fn s -> s.runner && s.runner.position end)
    |> Enum.filter(fn pos -> is_integer(pos) and pos >= 1 and pos <= 5 end)
    |> Enum.min(fn -> nil end)
  end

  defp already_replaced?(original_runner_id) do
    Repo.exists?(
      from(rr in RunnerReplacement, where: rr.original_runner_id == ^original_runner_id)
    )
  end

  defp points_for_position(1), do: 5
  defp points_for_position(2), do: 3
  defp points_for_position(3), do: 1
  defp points_for_position(_), do: 0

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([runners | rest]) do
    for runner_id <- runners, combo <- cartesian_product(rest) do
      [runner_id | combo]
    end
  end
end
