defmodule BetPlace.Repo.Migrations.AddVsPayoutAndManualSettlementToHvhMatchups do
  use Ecto.Migration

  def change do
    alter table(:hvh_matchups) do
      add :payout_pct, :decimal, precision: 5, scale: 2, null: false, default: 80.00
      add :settled_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :settlement_source, :string
      add :settled_at, :utc_datetime
    end

    create index(:hvh_matchups, [:settled_by_user_id])
    create index(:hvh_matchups, [:settlement_source])
    create constraint(:hvh_matchups, :hvh_matchups_payout_pct_positive, check: "payout_pct > 0")

    create constraint(:hvh_matchups, :hvh_matchups_settlement_source_valid,
             check:
               "settlement_source IN ('auto_sync','manual_admin') OR settlement_source IS NULL"
           )
  end
end
