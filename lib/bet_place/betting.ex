defmodule BetPlace.Betting do
  @moduledoc "Context for polla tickets, HvH matchups, and bets."

  import Ecto.Query
  alias BetPlace.Repo

  alias BetPlace.Betting.{
    PollaTicket,
    PollaSelection,
    PollaCombination,
    PollaCombinationSelection,
    HvhMatchup,
    HvhMatchupSide,
    HvhBet
  }

  alias BetPlace.Accounts.User
  alias BetPlace.Finance.Transaction
  alias BetPlace.Games.GameEvent

  # ── Place Polla Ticket (Ecto.Multi) ───────────────────────────────────────

  @doc """
  Places a polla ticket for a user on an open game event.

  `game_event` must be preloaded with `:game_config` and `game_event_races`.
  `selections` is a map of `%{game_event_race_id => [runner_id]}`.

  Returns `{:ok, %{ticket: ticket, debit_user: user, ...}}` or
  `{:error, failed_op, reason, changes}`.
  """
  def place_polla_ticket(user_id, %GameEvent{} = event, selections) do
    ordered_races = Enum.sort_by(event.game_event_races, & &1.race_order)

    ordered_selections =
      Enum.map(ordered_races, fn ger ->
        selections |> Map.get(ger.id, []) |> Enum.sort()
      end)

    combinations = cartesian_product(ordered_selections)
    combination_count = length(combinations)
    ticket_value = event.game_config.ticket_value || Decimal.new("1.00")
    total_paid = Decimal.mult(Decimal.new(combination_count), ticket_value)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ticket_cs =
      PollaTicket.changeset(%PollaTicket{}, %{
        game_event_id: event.id,
        user_id: user_id,
        combination_count: combination_count,
        ticket_value: ticket_value,
        total_paid: total_paid,
        sealed_at: now
      })

    Ecto.Multi.new()
    |> Ecto.Multi.run(:check_event, fn _repo, _ ->
      betting_closed =
        not is_nil(event.betting_closes_at) and
          DateTime.compare(event.betting_closes_at, now) != :gt

      cond do
        event.status != :open -> {:error, :event_not_open}
        betting_closed -> {:error, :betting_closed}
        combination_count == 0 -> {:error, :no_selections}
        true -> {:ok, event}
      end
    end)
    |> Ecto.Multi.run(:check_balance, fn repo, _ ->
      user = repo.get!(User, user_id)

      if Decimal.compare(user.balance, total_paid) != :lt do
        {:ok, user}
      else
        {:error, :insufficient_balance}
      end
    end)
    |> Ecto.Multi.insert(:ticket, ticket_cs)
    |> Ecto.Multi.insert_all(:selections, PollaSelection, fn %{ticket: ticket} ->
      for ger <- ordered_races, runner_id <- Map.get(selections, ger.id, []) do
        %{
          polla_ticket_id: ticket.id,
          game_event_race_id: ger.id,
          runner_id: runner_id,
          effective_runner_id: runner_id,
          inserted_at: now
        }
      end
    end)
    |> Ecto.Multi.insert_all(
      :combinations,
      PollaCombination,
      fn %{ticket: ticket} ->
        combinations
        |> Enum.with_index(1)
        |> Enum.map(fn {_combo, idx} ->
          %{
            polla_ticket_id: ticket.id,
            combination_index: idx,
            total_points: 0,
            is_winner: false,
            inserted_at: now,
            updated_at: now
          }
        end)
      end,
      returning: true
    )
    |> Ecto.Multi.insert_all(:combo_selections, PollaCombinationSelection, fn %{
                                                                                combinations:
                                                                                  {_, combos}
                                                                              } ->
      sorted_combos = Enum.sort_by(combos, & &1.combination_index)

      for {combo_record, combo_runners} <- Enum.zip(sorted_combos, combinations),
          {runner_id, ger} <- Enum.zip(combo_runners, ordered_races) do
        %{
          polla_combination_id: combo_record.id,
          game_event_race_id: ger.id,
          runner_id: runner_id,
          inserted_at: now
        }
      end
    end)
    |> Ecto.Multi.update(:debit_user, fn %{check_balance: user} ->
      User.balance_changeset(user, %{balance: Decimal.sub(user.balance, total_paid)})
    end)
    |> Ecto.Multi.insert(:transaction, fn %{check_balance: user, ticket: ticket} ->
      Transaction.changeset(%Transaction{}, %{
        user_id: user_id,
        type: :bet,
        direction: :debit,
        amount: total_paid,
        balance_before: user.balance,
        balance_after: Decimal.sub(user.balance, total_paid),
        reference_type: "polla_ticket",
        reference_id: ticket.id,
        status: :completed
      })
    end)
    |> Ecto.Multi.run(:update_pool, fn repo, _ ->
      event_fresh = repo.get!(GameEvent, event.id)
      new_pool = Decimal.add(event_fresh.total_pool, total_paid)
      event_fresh |> GameEvent.pool_changeset(%{total_pool: new_pool}) |> repo.update()
    end)
    |> Repo.transaction()
  end

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([runners | rest]) do
    for runner_id <- runners, combo <- cartesian_product(rest) do
      [runner_id | combo]
    end
  end

  # ── Polla Tickets ─────────────────────────────────────────────────────────

  def get_polla_ticket!(id) do
    PollaTicket
    |> preload([
      :game_event,
      :user,
      polla_selections: [:runner, :effective_runner],
      polla_combinations: []
    ])
    |> Repo.get!(id)
  end

  def list_polla_tickets_for_event(game_event_id) do
    PollaTicket
    |> where([pt], pt.game_event_id == ^game_event_id)
    |> preload(:user)
    |> Repo.all()
  end

  def list_polla_tickets_for_user(user_id) do
    PollaTicket
    |> where([pt], pt.user_id == ^user_id)
    |> order_by([pt], desc: pt.inserted_at)
    |> preload([:game_event, :polla_combinations])
    |> Repo.all()
  end

  def create_polla_ticket(attrs) do
    %PollaTicket{} |> PollaTicket.changeset(attrs) |> Repo.insert()
  end

  # ── Polla Selections ──────────────────────────────────────────────────────

  def create_polla_selection(attrs) do
    %PollaSelection{} |> PollaSelection.changeset(attrs) |> Repo.insert()
  end

  # ── Polla Combinations ────────────────────────────────────────────────────

  def create_polla_combination(attrs) do
    %PollaCombination{} |> PollaCombination.changeset(attrs) |> Repo.insert()
  end

  def list_combinations_for_ticket(polla_ticket_id) do
    PollaCombination
    |> where([pc], pc.polla_ticket_id == ^polla_ticket_id)
    |> order_by([pc], pc.combination_index)
    |> Repo.all()
  end

  # ── HvH Matchups ──────────────────────────────────────────────────────────

  def get_hvh_matchup!(id) do
    HvhMatchup
    |> preload([:race, :game_event, hvh_matchup_sides: :runner, hvh_bets: :user])
    |> Repo.get!(id)
  end

  def list_hvh_matchups_for_event(game_event_id) do
    HvhMatchup
    |> where([m], m.game_event_id == ^game_event_id)
    |> preload(hvh_matchup_sides: [runner: :horse])
    |> Repo.all()
  end

  def list_hvh_matchups_for_race(race_id) do
    HvhMatchup
    |> where([m], m.race_id == ^race_id)
    |> preload(hvh_matchup_sides: :runner)
    |> Repo.all()
  end

  def close_matchups_for_event(game_event_id) do
    {count, _} =
      HvhMatchup
      |> where([m], m.game_event_id == ^game_event_id and m.status == :open)
      |> Repo.update_all(set: [status: :closed])

    count
  end

  def create_hvh_matchup(attrs) do
    %HvhMatchup{} |> HvhMatchup.changeset(attrs) |> Repo.insert()
  end

  def update_hvh_matchup(%HvhMatchup{} = matchup, attrs) do
    matchup |> HvhMatchup.result_changeset(attrs) |> Repo.update()
  end

  def create_hvh_matchup_side(attrs) do
    %HvhMatchupSide{} |> HvhMatchupSide.changeset(attrs) |> Repo.insert()
  end

  # ── Place HvH Bet (Ecto.Multi) ────────────────────────────────────────────

  @doc """
  Places an HvH bet for a user.

  `matchup` must be preloaded with `:game_event` and `:game_event` with `:game_config`.
  `side` is `:a` or `:b`.
  `amount` is a Decimal (already validated as > 0).
  """
  def place_hvh_bet(user_id, %HvhMatchup{} = matchup, side, amount) do
    prize_multiplier =
      matchup.game_event.game_config.prize_multiplier || Decimal.new("1.80")

    potential_payout = Decimal.mult(amount, prize_multiplier)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    bet_cs =
      HvhBet.changeset(%HvhBet{}, %{
        hvh_matchup_id: matchup.id,
        user_id: user_id,
        side_chosen: side,
        amount: amount,
        potential_payout: potential_payout,
        placed_at: now
      })

    Ecto.Multi.new()
    |> Ecto.Multi.run(:check_matchup, fn _repo, _ ->
      cond do
        matchup.status != :open -> {:error, :matchup_not_open}
        matchup.game_event.status != :open -> {:error, :event_not_open}
        true -> {:ok, matchup}
      end
    end)
    |> Ecto.Multi.run(:check_min_stake, fn _repo, _ ->
      min = matchup.game_event.game_config.min_stake || Decimal.new("0")

      if Decimal.compare(amount, min) != :lt do
        {:ok, amount}
      else
        {:error, :below_min_stake}
      end
    end)
    |> Ecto.Multi.run(:check_balance, fn repo, _ ->
      user = repo.get!(User, user_id)

      if Decimal.compare(user.balance, amount) != :lt do
        {:ok, user}
      else
        {:error, :insufficient_balance}
      end
    end)
    |> Ecto.Multi.insert(:bet, bet_cs)
    |> Ecto.Multi.update(:debit_user, fn %{check_balance: user} ->
      User.balance_changeset(user, %{balance: Decimal.sub(user.balance, amount)})
    end)
    |> Ecto.Multi.insert(:transaction, fn %{check_balance: user, bet: bet} ->
      Transaction.changeset(%Transaction{}, %{
        user_id: user_id,
        type: :bet,
        direction: :debit,
        amount: amount,
        balance_before: user.balance,
        balance_after: Decimal.sub(user.balance, amount),
        reference_type: "hvh_bet",
        reference_id: bet.id,
        status: :completed
      })
    end)
    |> Ecto.Multi.run(:update_matchup, fn repo, _ ->
      fresh = repo.get!(HvhMatchup, matchup.id)

      {new_a, new_b} =
        if side == :a,
          do: {Decimal.add(fresh.total_side_a, amount), fresh.total_side_b},
          else: {fresh.total_side_a, Decimal.add(fresh.total_side_b, amount)}

      fresh
      |> HvhMatchup.result_changeset(%{
        total_side_a: new_a,
        total_side_b: new_b,
        total_pool: Decimal.add(fresh.total_pool, amount)
      })
      |> repo.update()
    end)
    |> Repo.transaction()
  end

  # ── HvH Bets ──────────────────────────────────────────────────────────────

  def get_hvh_bet!(id), do: Repo.get!(HvhBet, id)

  def list_hvh_bets_for_matchup(matchup_id) do
    HvhBet
    |> where([b], b.hvh_matchup_id == ^matchup_id)
    |> preload(:user)
    |> Repo.all()
  end

  def list_hvh_bets_for_user(user_id) do
    HvhBet
    |> where([b], b.user_id == ^user_id)
    |> order_by([b], desc: b.placed_at)
    |> preload(hvh_matchup: [:race, :game_event])
    |> Repo.all()
  end

  def create_hvh_bet(attrs) do
    %HvhBet{} |> HvhBet.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Creates an HvH matchup and its two sides in one transaction.
  `side_a_runner_ids` and `side_b_runner_ids` are lists of runner UUIDs.
  """
  def create_hvh_matchup_with_sides(matchup_attrs, side_a_runner_ids, side_b_runner_ids) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:matchup, HvhMatchup.changeset(%HvhMatchup{}, matchup_attrs))
    |> Ecto.Multi.run(:sides, fn repo, %{matchup: matchup} ->
      Enum.each(side_a_runner_ids, fn runner_id ->
        repo.insert!(%HvhMatchupSide{hvh_matchup_id: matchup.id, side: :a, runner_id: runner_id})
      end)

      Enum.each(side_b_runner_ids, fn runner_id ->
        repo.insert!(%HvhMatchupSide{hvh_matchup_id: matchup.id, side: :b, runner_id: runner_id})
      end)

      {:ok, :ok}
    end)
    |> Repo.transaction()
  end

  def count_tickets, do: Repo.aggregate(HvhBet, :count)

  # ── Admin listing ─────────────────────────────────────────────────────────

  def list_polla_tickets_for_user_and_event(user_id, event_id) do
    PollaTicket
    |> where([pt], pt.user_id == ^user_id and pt.game_event_id == ^event_id)
    |> order_by([pt], desc: pt.inserted_at)
    |> preload(polla_selections: [game_event_race: :race, runner: [:horse]])
    |> Repo.all()
  end

  def list_hvh_bets_for_user_and_event(user_id, event_id) do
    HvhBet
    |> join(:inner, [b], m in assoc(b, :hvh_matchup))
    |> where([b, m], b.user_id == ^user_id and m.game_event_id == ^event_id)
    |> order_by([b], desc: b.placed_at)
    |> preload(hvh_matchup: [:race, hvh_matchup_sides: [runner: [:horse]]])
    |> Repo.all()
  end

  def list_all_polla_tickets do
    PollaTicket
    |> order_by([pt], desc: pt.inserted_at)
    |> preload([:user, :game_event])
    |> Repo.all()
  end

  def list_all_hvh_bets do
    HvhBet
    |> order_by([b], desc: b.placed_at)
    |> preload([:user, hvh_matchup: [:game_event, race: [:course]]])
    |> Repo.all()
  end
end
