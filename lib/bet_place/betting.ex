defmodule BetPlace.Betting do
  @moduledoc "Context for polla tickets, HvH matchups, and bets."

  import Ecto.Query
  alias BetPlace.Repo

  alias BetPlace.Betting.{
    PollaTicket,
    PollaSelection,
    PollaCombination,
    HvhMatchup,
    HvhMatchupSide,
    HvhBet
  }

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
    |> preload(:game_event)
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
    |> preload(hvh_matchup_sides: :runner)
    |> Repo.all()
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
    |> order_by([b], desc: b.inserted_at)
    |> preload(hvh_matchup: :race)
    |> Repo.all()
  end

  def create_hvh_bet(attrs) do
    %HvhBet{} |> HvhBet.changeset(attrs) |> Repo.insert()
  end
end
