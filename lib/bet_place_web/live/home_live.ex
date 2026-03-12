defmodule BetPlaceWeb.HomeLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Accounts.Scope

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center py-12">
        <h1 class="text-4xl font-bold mb-4">Bet Place</h1>
        <p class="text-xl text-base-content/60 mb-8">Plataforma de apuestas hípicas</p>

        <%= if @current_scope do %>
          <p class="mb-6">
            Bienvenido, <strong>{@current_scope.user.username}</strong>
          </p>
          <div class="flex justify-center gap-4">
            <.link navigate={~p"/eventos"} class="btn btn-primary">
              Ver eventos
            </.link>
            <%= if Scope.admin?(@current_scope) do %>
              <.link navigate={~p"/admin"} class="btn btn-secondary">
                Panel admin
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="flex justify-center gap-4">
            <.link navigate={~p"/login"} class="btn btn-primary">
              Iniciar sesión
            </.link>
            <.link navigate={~p"/register"} class="btn btn-outline">
              Registrarse
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
