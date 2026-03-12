defmodule BetPlaceWeb.UserRegistrationLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.Accounts
  alias BetPlace.Accounts.User

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold">Crear cuenta</h1>
          <p class="mt-2 text-base-content/60">Únete a la plataforma de apuestas hípicas</p>
        </div>

        <div class="card bg-base-100 shadow-xl border border-base-200">
          <div class="card-body">
            <.form
              for={@form}
              id="registration-form"
              phx-submit="save"
              phx-change="validate"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Correo electrónico"
                placeholder="usuario@ejemplo.com"
                required
              />
              <.input
                field={@form[:username]}
                type="text"
                label="Nombre de usuario"
                placeholder="apuestador123"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Contraseña"
                placeholder="Mínimo 8 caracteres"
                required
              />
              <button
                type="submit"
                class="btn btn-primary w-full mt-4"
                phx-disable-with="Registrando..."
              >
                Registrarse
              </button>
            </.form>

            <div class="divider text-xs text-base-content/40">¿Ya tienes cuenta?</div>

            <.link navigate={~p"/login"} class="btn btn-outline w-full">
              Iniciar sesión
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    {:ok, assign(socket, form: to_form(changeset))}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.create_user(params) do
      {:ok, user} ->
        token = Accounts.create_user_session_token(user)

        {:noreply,
         socket
         |> put_flash(:info, "¡Cuenta creada! Bienvenido, #{user.username}.")
         |> push_navigate(to: ~p"/")}
        |> tap(fn _ ->
          BetPlaceWeb.Endpoint.broadcast(
            "users_sessions:#{Base.url_encode64(token)}",
            "disconnect",
            %{}
          )
        end)

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
