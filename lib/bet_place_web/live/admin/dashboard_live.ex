defmodule BetPlaceWeb.Admin.DashboardLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Accounts, Games, Racing}
  alias BetPlace.Api.SyncWorker

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold">Panel de Administración</h1>
            <p class="text-base-content/60 mt-1">Bienvenido, {@current_scope.user.username}</p>
          </div>
          <button
            phx-click="sync_now"
            class="btn btn-outline btn-sm gap-2"
            phx-disable-with="Sincronizando..."
          >
            <.icon name="hero-arrow-path" class="size-4" /> Sync API ahora
          </button>
        </div>

        <%!-- Stats cards --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold text-primary">{@stats.total_users}</div>
              <div class="text-sm text-base-content/60">Usuarios</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold text-secondary">{@stats.total_courses}</div>
              <div class="text-sm text-base-content/60">Hipódromos</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold text-accent">{@stats.total_races}</div>
              <div class="text-sm text-base-content/60">Carreras sincronizadas</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="text-3xl font-bold text-success">{@stats.open_events}</div>
              <div class="text-sm text-base-content/60">Eventos abiertos</div>
            </div>
          </div>
        </div>

        <%!-- Quick actions --%>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-lg">Gestión de Eventos</h2>
              <p class="text-sm text-base-content/60">Crea y administra eventos de apuestas.</p>
              <div class="card-actions mt-2">
                <.link navigate={~p"/admin/eventos"} class="btn btn-primary btn-sm">
                  Ver eventos
                </.link>
                <.link navigate={~p"/admin/eventos/nuevo"} class="btn btn-outline btn-sm">
                  Crear evento
                </.link>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-lg">Usuarios</h2>
              <p class="text-sm text-base-content/60">
                {@stats.total_users} registrados · {@stats.bettors} apostadores
              </p>
              <div class="card-actions mt-2">
                <.link navigate={~p"/admin/usuarios"} class="btn btn-primary btn-sm">
                  Ver usuarios
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    stats = load_stats()
    {:ok, assign(socket, stats: stats)}
  end

  def handle_event("sync_now", _params, socket) do
    SyncWorker.sync_now(:all)

    {:noreply,
     socket
     |> put_flash(:info, "Sincronización iniciada en segundo plano.")}
  end

  defp load_stats do
    by_role = Accounts.count_users_by_role()
    event_counts = Games.count_game_events_by_status()

    %{
      total_users: Accounts.count_users(),
      bettors: Map.get(by_role, :bettor, 0),
      total_courses: Racing.count_courses(),
      total_races: Racing.count_races(),
      open_events: Map.get(event_counts, :open, 0)
    }
  end
end
