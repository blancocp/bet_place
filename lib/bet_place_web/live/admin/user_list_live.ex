defmodule BetPlaceWeb.Admin.UserListLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="mb-6">
          <h1 class="text-3xl font-bold">Usuarios</h1>
          <p class="text-base-content/60 mt-1">Gestión de cuentas de usuario</p>
        </div>

        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body p-0">
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Usuario</th>
                    <th>Email</th>
                    <th>Rol</th>
                    <th>Estado</th>
                    <th>Saldo</th>
                    <th>Registrado</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody id="users" phx-update="stream">
                  <tr :for={{dom_id, user} <- @streams.users} id={dom_id} class="hover">
                    <td class="font-medium">{user.username}</td>
                    <td class="text-sm text-base-content/70">{user.email}</td>
                    <td>
                      <span class={["badge badge-sm", role_badge_class(user.role)]}>
                        {role_label(user.role)}
                      </span>
                    </td>
                    <td>
                      <span class={["badge badge-sm", status_badge_class(user.status)]}>
                        {status_label(user.status)}
                      </span>
                    </td>
                    <td class="font-mono text-sm">${user.balance}</td>
                    <td class="text-sm text-base-content/60">
                      {Calendar.strftime(user.inserted_at, "%d/%m/%Y")}
                    </td>
                    <td>
                      <%= if user.status == :active do %>
                        <button
                          phx-click="suspend_user"
                          phx-value-id={user.id}
                          class="btn btn-xs btn-warning"
                          data-confirm={"¿Suspender a #{user.username}?"}
                        >
                          Suspender
                        </button>
                      <% else %>
                        <button
                          phx-click="activate_user"
                          phx-value-id={user.id}
                          class="btn btn-xs btn-success"
                          data-confirm={"¿Activar a #{user.username}?"}
                        >
                          Activar
                        </button>
                      <% end %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    {:ok, stream(socket, :users, users)}
  end

  def handle_event("suspend_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.update_user_status(user, :suspended) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Usuario #{updated.username} suspendido.")
         |> stream_insert(:users, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo suspender el usuario.")}
    end
  end

  def handle_event("activate_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.update_user_status(user, :active) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Usuario #{updated.username} activado.")
         |> stream_insert(:users, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo activar el usuario.")}
    end
  end

  defp role_badge_class(:admin), do: "badge-primary"
  defp role_badge_class(:bettor), do: "badge-ghost"
  defp role_badge_class(_), do: "badge-ghost"

  defp role_label(:admin), do: "Admin"
  defp role_label(:bettor), do: "Apostador"
  defp role_label(other), do: to_string(other)

  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:suspended), do: "badge-warning"
  defp status_badge_class(:banned), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  defp status_label(:active), do: "Activo"
  defp status_label(:suspended), do: "Suspendido"
  defp status_label(:banned), do: "Baneado"
  defp status_label(other), do: to_string(other)
end
