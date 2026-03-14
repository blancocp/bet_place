defmodule BetPlaceWeb.Admin.DashboardLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Accounts, Games, Racing}
  alias BetPlace.Api.{SyncWorker, SyncSettings}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold">Panel de Administración</h1>
            <p class="text-base-content/60 mt-1">Bienvenido, {@current_scope.user.username}</p>
          </div>
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

        <%!-- API Sync control --%>
        <div class="card bg-base-100 border border-base-200 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg">
              <.icon name="hero-arrow-path" class="size-5" /> Control de API
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Plan BASIC: cuota limitada. El sync global trae todos los hipódromos.
              Usa "Sync carreras" en cada evento para sincronizar solo lo necesario.
            </p>

            <%!-- Auto-sync toggle --%>
            <div class="flex items-center justify-between p-3 rounded-lg bg-base-200 mb-4">
              <div>
                <div class="font-medium text-sm">Sync automático</div>
                <div class="text-xs text-base-content/60">
                  Racecards cada 30 min · Resultados cada 60 s (12–23 UTC)
                </div>
              </div>
              <div class="flex items-center gap-3">
                <span class={[
                  "badge badge-sm",
                  if(@auto_sync_enabled, do: "badge-success", else: "badge-error")
                ]}>
                  {if @auto_sync_enabled, do: "ACTIVO", else: "INACTIVO"}
                </span>
                <button
                  phx-click="toggle_auto_sync"
                  class={[
                    "btn btn-sm",
                    if(@auto_sync_enabled,
                      do: "btn-error btn-outline",
                      else: "btn-success btn-outline"
                    )
                  ]}
                >
                  {if @auto_sync_enabled, do: "Desactivar", else: "Activar"}
                </button>
              </div>
            </div>

            <%!-- Manual sync buttons --%>
            <div class="flex flex-wrap items-end gap-3">
              <div>
                <label class="label text-xs pb-1">Fecha de sync</label>
                <input
                  type="date"
                  name="sync_date"
                  value={@sync_date}
                  phx-change="set_sync_date"
                  class="input input-bordered input-sm w-40"
                />
              </div>
              <button
                phx-click="sync_racecards"
                class="btn btn-outline btn-sm gap-2"
                phx-disable-with="Sincronizando..."
              >
                <.icon name="hero-calendar" class="size-4" /> Sync Racecards
              </button>
              <button
                phx-click="sync_results"
                class="btn btn-outline btn-sm gap-2"
                phx-disable-with="Sincronizando..."
              >
                <.icon name="hero-flag" class="size-4" /> Sync Resultados
              </button>
              <button
                phx-click="sync_all"
                class="btn btn-primary btn-sm gap-2"
                phx-disable-with="Sincronizando..."
              >
                <.icon name="hero-arrow-path" class="size-4" /> Sync Todo
              </button>
            </div>
            <p class="text-xs text-base-content/40 mt-2">
              Sync Resultados solo descarga detalles de carreras con eventos activos.
            </p>
          </div>
        </div>

        <%!-- Quick actions --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
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
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-lg">Tickets</h2>
              <p class="text-sm text-base-content/60">Polla Hípica y Horse vs Horse.</p>
              <div class="card-actions mt-2">
                <.link navigate={~p"/admin/tickets"} class="btn btn-primary btn-sm">
                  Ver tickets
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
    auto_sync_enabled = SyncSettings.auto_sync_enabled?()
    today = Date.to_string(Date.utc_today())

    {:ok,
     assign(socket,
       stats: stats,
       auto_sync_enabled: auto_sync_enabled,
       sync_date: today
     )}
  end

  def handle_event("set_sync_date", %{"sync_date" => date}, socket) do
    {:noreply, assign(socket, :sync_date, date)}
  end

  def handle_event("toggle_auto_sync", _params, socket) do
    new_value = not socket.assigns.auto_sync_enabled

    case SyncSettings.set_auto_sync(new_value) do
      :ok ->
        msg =
          if new_value,
            do: "Sync automático activado.",
            else: "Sync automático desactivado. Los syncs manuales siguen disponibles."

        {:noreply, socket |> assign(auto_sync_enabled: new_value) |> put_flash(:info, msg)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Error al guardar la configuración. Revisa los logs del servidor."
         )}
    end
  end

  def handle_event("sync_racecards", _params, socket) do
    date = socket.assigns.sync_date
    SyncWorker.sync_now(:racecards, date)

    {:noreply, socket |> put_flash(:info, "Sync de racecards para #{date} iniciado (1 request).")}
  end

  def handle_event("sync_results", _params, socket) do
    date = socket.assigns.sync_date
    SyncWorker.sync_now(:results, date)

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Sync de resultados para #{date} iniciado (solo cursos con eventos activos)."
     )}
  end

  def handle_event("sync_all", _params, socket) do
    date = socket.assigns.sync_date
    SyncWorker.sync_now(:racecards, date)
    SyncWorker.sync_now(:results, date)

    {:noreply, socket |> put_flash(:info, "Sync completo para #{date} iniciado.")}
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
