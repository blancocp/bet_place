defmodule BetPlaceWeb.Admin.DashboardLive do
  use BetPlaceWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <h1 class="text-3xl font-bold mb-6">Panel de Administración</h1>
        <p class="text-base-content/60">
          Administrador: <strong>{@current_scope.user.email}</strong>
        </p>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
