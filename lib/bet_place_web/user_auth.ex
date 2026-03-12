defmodule BetPlaceWeb.UserAuth do
  @moduledoc "Authentication plug and LiveView on_mount hooks."

  use BetPlaceWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias BetPlace.Accounts
  alias BetPlace.Accounts.Scope

  # ── Plug callbacks ────────────────────────────────────────────────────────

  @doc "Fetches current user from session and assigns current_scope."
  def fetch_current_scope(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    current_scope =
      case user_token && Accounts.get_user_by_session_token(user_token) do
        nil -> nil
        user -> Accounts.build_scope(user)
      end

    assign(conn, :current_scope, current_scope)
  end

  @doc "Requires authenticated user. Redirects to login if not authenticated."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_flash(:error, "Debes iniciar sesión para acceder.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc "Requires admin role."
  def require_admin(conn, _opts) do
    cond do
      is_nil(conn.assigns[:current_scope]) ->
        conn
        |> put_flash(:error, "Debes iniciar sesión para acceder.")
        |> redirect(to: ~p"/login")
        |> halt()

      not Scope.admin?(conn.assigns[:current_scope]) ->
        conn
        |> put_flash(:error, "No tienes permisos para acceder a esta sección.")
        |> redirect(to: ~p"/")
        |> halt()

      true ->
        conn
    end
  end

  @doc "Redirects logged-in users away from guest-only pages."
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn |> redirect(to: ~p"/") |> halt()
    else
      conn
    end
  end

  # ── Session management ────────────────────────────────────────────────────

  @doc "Logs in a user: creates session token, writes cookie, redirects."
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.create_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_remember_me(params)
    |> redirect(to: user_return_to || signed_in_path(user))
  end

  @doc "Logs out: deletes token, disconnects LiveSocket, redirects home."
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      BetPlaceWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn |> renew_session() |> redirect(to: ~p"/")
  end

  # ── LiveView on_mount hooks ───────────────────────────────────────────────

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Debes iniciar sesión para acceder.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    cond do
      is_nil(socket.assigns.current_scope) ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "Debes iniciar sesión para acceder.")
          |> Phoenix.LiveView.redirect(to: ~p"/login")

        {:halt, socket}

      not Scope.admin?(socket.assigns.current_scope) ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "No tienes permisos para acceder a esta sección.")
          |> Phoenix.LiveView.redirect(to: ~p"/")

        {:halt, socket}

      true ->
        {:cont, socket}
    end
  end

  # ── Private helpers ───────────────────────────────────────────────────────

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        session["user_token"] &&
          Accounts.get_user_by_session_token(session["user_token"])

      user && Accounts.build_scope(user)
    end)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      {nil, conn}
    end
  end

  defp renew_session(conn) do
    delete_csrf_token()
    conn |> configure_session(renew: true) |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_remember_me(conn, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, "remember_me", "true", sign: true, max_age: 60 * 60 * 24 * 60)
  end

  defp maybe_remember_me(conn, _), do: conn

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(%{role: :admin}), do: ~p"/admin"
  defp signed_in_path(_user), do: ~p"/"
end
