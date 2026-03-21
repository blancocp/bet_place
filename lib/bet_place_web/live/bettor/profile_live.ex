defmodule BetPlaceWeb.Bettor.ProfileLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Accounts, Finance}
  alias BetPlace.Finance.PaymentMethod

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:user_payment_methods, Finance.list_user_payment_methods(user.id))
     |> assign(:bank_options, Finance.bank_options())
     |> assign(:profile_form, to_form(Accounts.change_user_profile(user), as: :profile))
     |> assign(:password_form, to_form(Accounts.change_user_password(user), as: :password))
     |> assign(
       :payment_method_form,
       to_form(Finance.change_payment_method(%PaymentMethod{}), as: :payment_method)
     )}
  end

  def handle_event("validate_profile", %{"profile" => params}, socket) do
    user = socket.assigns.current_scope.user
    changeset = Accounts.change_user_profile(user, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :profile_form, to_form(changeset, as: :profile))}
  end

  def handle_event("save_profile", %{"profile" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_profile(user, params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Accounts.build_scope(updated_user))
         |> assign(
           :profile_form,
           to_form(Accounts.change_user_profile(updated_user), as: :profile)
         )
         |> put_flash(:info, "Perfil personal actualizado.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset, as: :profile))}
    end
  end

  def handle_event("validate_password", %{"password" => params}, socket) do
    user = socket.assigns.current_scope.user
    changeset = Accounts.change_user_password(user, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :password_form, to_form(changeset, as: :password))}
  end

  def handle_event("save_password", %{"password" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Accounts.build_scope(updated_user))
         |> assign(
           :password_form,
           to_form(Accounts.change_user_password(updated_user), as: :password)
         )
         |> put_flash(:info, "Contraseña actualizada.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form, to_form(changeset, as: :password))}
    end
  end

  def handle_event("validate_payment_method", %{"payment_method" => params}, socket) do
    user = socket.assigns.current_scope.user

    params =
      params
      |> Map.put("owner_type", "user")
      |> Map.put("user_id", user.id)

    changeset =
      Finance.change_payment_method(%PaymentMethod{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :payment_method_form, to_form(changeset, as: :payment_method))}
  end

  def handle_event("save_payment_method", %{"payment_method" => params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      params
      |> Map.put("owner_type", "user")
      |> Map.put("user_id", user.id)

    case Finance.create_payment_method(attrs) do
      {:ok, _method} ->
        {:noreply,
         socket
         |> assign(:user_payment_methods, Finance.list_user_payment_methods(user.id))
         |> assign(
           :payment_method_form,
           to_form(Finance.change_payment_method(%PaymentMethod{}), as: :payment_method)
         )
         |> put_flash(:info, "Método de pago agregado.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :payment_method_form, to_form(changeset, as: :payment_method))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h1 class="card-title text-2xl">Mi perfil personal</h1>
            <.form
              for={@profile_form}
              id="profile-form"
              phx-change="validate_profile"
              phx-submit="save_profile"
              class="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
              <.input field={@profile_form[:first_name]} type="text" label="Nombre" />
              <.input field={@profile_form[:last_name]} type="text" label="Apellidos" />
              <.input field={@profile_form[:birth_date]} type="date" label="Fecha de nacimiento" />
              <.input field={@profile_form[:identity_document]} type="text" label="Cédula" />
              <.input field={@profile_form[:phone_number]} type="text" label="Teléfono" />
              <.input field={@profile_form[:address]} type="text" label="Dirección" />

              <div class="md:col-span-2">
                <button class="btn btn-primary btn-sm">Guardar perfil</button>
              </div>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Cambiar contraseña</h2>
            <.form
              for={@password_form}
              id="password-form"
              phx-change="validate_password"
              phx-submit="save_password"
              class="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
              <.input
                field={@password_form[:password]}
                type="password"
                label="Nueva contraseña"
                value=""
              />
              <div class="md:col-span-2">
                <button class="btn btn-secondary btn-sm">Actualizar contraseña</button>
              </div>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Perfil financiero</h2>
            <p class="text-sm text-base-content/60">
              Puedes registrar múltiples cuentas bancarias o métodos de pago móvil.
            </p>

            <div class="overflow-x-auto mb-4">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Tipo</th>
                    <th>Banco</th>
                    <th>Titular</th>
                    <th>Cuenta/Teléfono</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={method <- @user_payment_methods}>
                    <td>{if method.type == :bank_account, do: "Cuenta", else: "Pago móvil"}</td>
                    <td>{method.bank_code}</td>
                    <td>{method.holder_identity_document}</td>
                    <td>{method.account_number || method.phone_number}</td>
                  </tr>
                  <tr :if={@user_payment_methods == []}>
                    <td colspan="4" class="text-center text-base-content/50 py-4">
                      No tienes métodos registrados.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <.form
              for={@payment_method_form}
              id="payment-method-form"
              phx-change="validate_payment_method"
              phx-submit="save_payment_method"
              class="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
              <.input
                field={@payment_method_form[:type]}
                type="select"
                label="Tipo"
                options={[{"Cuenta bancaria", "bank_account"}, {"Pago móvil", "mobile_payment"}]}
              />
              <.input
                field={@payment_method_form[:bank_code]}
                type="select"
                label="Banco"
                options={@bank_options}
              />
              <.input
                field={@payment_method_form[:holder_identity_document]}
                type="text"
                label="Cédula del titular"
              />
              <.input
                field={@payment_method_form[:account_number]}
                type="text"
                label="Número de cuenta (20 dígitos)"
              />
              <.input
                field={@payment_method_form[:phone_number]}
                type="text"
                label="Número de teléfono (11 dígitos)"
              />
              <.input field={@payment_method_form[:label]} type="text" label="Etiqueta (opcional)" />
              <div class="md:col-span-2">
                <button class="btn btn-primary btn-sm">Agregar método</button>
              </div>
            </.form>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
