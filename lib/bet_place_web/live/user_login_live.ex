defmodule BetPlaceWeb.UserLoginLive do
  use BetPlaceWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold">Iniciar sesión</h1>
          <p class="mt-2 text-base-content/60">Ingresa tus credenciales para continuar</p>
        </div>

        <div class="card bg-base-100 shadow-xl border border-base-200">
          <div class="card-body">
            <.form for={@form} id="login-form" action={~p"/login"} method="post">
              <.input
                field={@form[:email]}
                type="email"
                label="Correo electrónico"
                placeholder="usuario@ejemplo.com"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Contraseña"
                placeholder="••••••••"
                required
              />
              <.input
                field={@form[:remember_me]}
                type="checkbox"
                label="Mantener sesión iniciada"
              />
              <button type="submit" class="btn btn-primary w-full mt-4">
                Ingresar
              </button>
            </.form>

            <div class="divider text-xs text-base-content/40">¿No tienes cuenta?</div>

            <.link navigate={~p"/register"} class="btn btn-outline w-full">
              Crear cuenta
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => nil, "password" => nil, "remember_me" => false}, as: :user)
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end
end
