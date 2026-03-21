defmodule BetPlace.FinanceTest do
  use BetPlace.DataCase, async: true

  alias BetPlace.{Accounts, Finance, Repo}
  alias BetPlace.Finance.{PaymentReport, Transaction}

  defp user_attrs(suffix) do
    %{
      email: "user#{suffix}@example.com",
      username: "user#{suffix}",
      password: "supersecret123"
    }
  end

  defp create_user!(suffix) do
    {:ok, user} = Accounts.create_user(user_attrs(suffix))
    user
  end

  describe "payment methods" do
    test "create user payment method enforces same identity document" do
      user = create_user!("100")
      {:ok, user} = Accounts.update_user_profile(user, profile_attrs("12345678"))

      attrs = %{
        owner_type: :user,
        user_id: user.id,
        type: :bank_account,
        bank_code: "0102",
        holder_identity_document: "87654321",
        account_number: "01020000000000000000"
      }

      assert {:error, changeset} = Finance.create_payment_method(attrs)
      assert "debe coincidir con tu cédula" in errors_on(changeset).holder_identity_document
    end
  end

  describe "payment reports" do
    test "approve payment report updates balance and creates ledger entry" do
      admin = create_user!("200")
      {:ok, admin} = Accounts.update_user(admin, %{role: :admin})

      bettor = create_user!("201")
      {:ok, bettor} = Accounts.update_user_profile(bettor, profile_attrs("22334455"))

      {:ok, method} =
        Finance.create_payment_method(%{
          owner_type: :system,
          type: :bank_account,
          bank_code: "0102",
          holder_identity_document: "22334455",
          account_number: "01020000000000000001"
        })

      {:ok, report} =
        Finance.create_payment_report(%{
          user_id: bettor.id,
          payment_method_id: method.id,
          channel: :bank_transfer,
          amount: Decimal.new("20.00"),
          payer_identity_document: "22334455",
          reference_number: "REF-001"
        })

      assert {:ok, %{report: %PaymentReport{status: :approved}, user: user, transaction: tx}} =
               Finance.approve_payment_report(report.id, admin.id, Decimal.new("18.50"), nil)

      assert Decimal.equal?(user.balance, Decimal.new("18.50"))
      assert tx.type == :deposit
      assert tx.direction == :credit
      assert tx.reference_id == report.id
    end
  end

  describe "manual adjustments" do
    test "manual adjustment creates manual_adjustment transaction" do
      admin = create_user!("300")
      {:ok, admin} = Accounts.update_user(admin, %{role: :admin})
      bettor = create_user!("301")

      assert {:ok, %{transaction: %Transaction{} = tx}} =
               Finance.apply_manual_balance_adjustment(
                 bettor.id,
                 admin.id,
                 Decimal.new("10.00"),
                 "Ajuste de prueba"
               )

      assert tx.type == :manual_adjustment
      assert tx.direction == :credit

      reloaded = Repo.get!(BetPlace.Accounts.User, bettor.id)
      assert Decimal.equal?(reloaded.balance, Decimal.new("10.00"))
    end
  end

  defp profile_attrs(identity_document) do
    %{
      first_name: "Carlos",
      last_name: "Perez",
      birth_date: ~D[1990-01-01],
      identity_document: identity_document,
      address: "Av Principal",
      phone_number: "04121234567"
    }
  end
end
