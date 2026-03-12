defmodule BetPlaceWeb.PageController do
  use BetPlaceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
