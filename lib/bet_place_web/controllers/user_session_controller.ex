defmodule BetPlaceWeb.UserSessionController do
  use BetPlaceWeb, :controller

  alias BetPlace.Accounts
  alias BetPlaceWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Bienvenido de nuevo, #{user.username}.")
        |> UserAuth.log_in_user(user, user_params)

      {:error, :account_inactive} ->
        conn
        |> put_flash(:error, "Tu cuenta está inactiva. Contacta al administrador.")
        |> redirect(to: ~p"/login")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Correo o contraseña incorrectos.")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Sesión cerrada correctamente.")
    |> UserAuth.log_out_user()
  end
end
