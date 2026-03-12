defmodule BetPlaceWeb.PageControllerTest do
  use BetPlaceWeb.ConnCase

  test "GET / renders home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Bet Place"
  end

  test "GET /login renders login page", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "Iniciar sesión"
  end

  test "GET /register renders registration page", %{conn: conn} do
    conn = get(conn, ~p"/register")
    assert html_response(conn, 200) =~ "Crear cuenta"
  end
end
