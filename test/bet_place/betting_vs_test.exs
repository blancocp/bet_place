defmodule BetPlace.BettingVsTest do
  use ExUnit.Case, async: true

  alias BetPlace.Betting
  alias BetPlace.Betting.HvhMatchup

  test "payout multiplier uses matchup payout_pct" do
    matchup = %HvhMatchup{payout_pct: Decimal.new("80.00")}
    assert Decimal.equal?(Betting.payout_multiplier_for_matchup(matchup), Decimal.new("1.80"))
  end

  test "side labels map to Macho/Hembra" do
    assert Betting.side_label(:a) == "Macho"
    assert Betting.side_label(:b) == "Hembra"
  end
end
