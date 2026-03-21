defmodule BetPlaceWeb.Bettor.PaymentsLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Accounts, Finance}
  alias BetPlace.Finance.PaymentReport

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    system_payment_methods = Finance.list_system_payment_methods()
    default_channel = default_channel_for_methods(system_payment_methods)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(BetPlace.PubSub, "user:#{user_id}")
    end

    {:ok,
     socket
     |> assign(:system_payment_methods, system_payment_methods)
     |> assign(:payment_reports, Finance.list_payment_reports_for_user(user_id))
     |> assign(
       :report_form,
       to_form(Finance.change_payment_report(%PaymentReport{}, %{"channel" => default_channel}),
         as: :report
       )
     )}
  end

  def handle_info({:balance_updated, _new_balance}, socket) do
    user = Accounts.get_user!(socket.assigns.current_scope.user.id)

    {:noreply,
     socket
     |> assign(:current_scope, Accounts.build_scope(user))
     |> assign(:payment_reports, Finance.list_payment_reports_for_user(user.id))}
  end

  def handle_info({:payment_report_reviewed, _report_id, _status}, socket) do
    user_id = socket.assigns.current_scope.user.id

    {:noreply, assign(socket, :payment_reports, Finance.list_payment_reports_for_user(user_id))}
  end

  def handle_event("validate_report", %{"report" => params}, socket) do
    user = socket.assigns.current_scope.user
    synced_params = sync_channel_with_method(params, socket.assigns.system_payment_methods)
    attrs = Map.put(synced_params, "user_id", user.id)

    changeset =
      Finance.change_payment_report(%PaymentReport{}, attrs) |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:report_form, to_form(changeset, as: :report))}
  end

  def handle_event("save_report", %{"report" => params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      params
      |> sync_channel_with_method(socket.assigns.system_payment_methods)
      |> Map.put("user_id", user.id)
      |> Map.put("reported_at", DateTime.utc_now() |> DateTime.truncate(:second))

    case Finance.create_payment_report(attrs) do
      {:ok, _report} ->
        default_channel = default_channel_for_methods(socket.assigns.system_payment_methods)

        {:noreply,
         socket
         |> assign(:payment_reports, Finance.list_payment_reports_for_user(user.id))
         |> assign(
           :report_form,
           to_form(
             Finance.change_payment_report(%PaymentReport{}, %{"channel" => default_channel}),
             as: :report
           )
         )
         |> put_flash(:info, "Pago reportado. Un administrador lo revisará.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :report_form, to_form(changeset, as: :report))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h1 class="card-title text-2xl">Información de pago</h1>
            <p class="text-sm text-base-content/60">
              Usa uno de estos métodos para transferencias o pago móvil y luego reporta tu recarga.
            </p>

            <div class="overflow-x-auto">
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
                  <tr :for={method <- @system_payment_methods}>
                    <td>
                      {if method.type == :bank_account, do: "Transferencia", else: "Pago móvil"}
                    </td>
                    <td>{method.bank_code}</td>
                    <td>{method.holder_identity_document}</td>
                    <td>{method.account_number || method.phone_number}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Reportar pago para recarga</h2>
            <.form
              for={@report_form}
              id="payment-report-form"
              phx-change="validate_report"
              phx-submit="save_report"
              class="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
              <.input
                field={@report_form[:payment_method_id]}
                type="select"
                label="Método de pago usado"
                options={
                  Enum.map(@system_payment_methods, fn method ->
                    {
                      "#{if(method.type == :bank_account, do: "Cuenta", else: "Pago móvil")} #{method.bank_code} - #{method.account_number || method.phone_number}",
                      method.id
                    }
                  end)
                }
              />
              <.input
                field={@report_form[:channel]}
                type="select"
                label="Canal (definido por el método)"
                options={[{"Transferencia", "bank_transfer"}, {"Pago móvil", "mobile_payment"}]}
                disabled
              />
              <.input field={@report_form[:channel]} type="hidden" />
              <.input field={@report_form[:amount]} type="number" step="0.01" label="Monto" />
              <.input
                field={@report_form[:payer_identity_document]}
                type="text"
                label="Cédula del titular"
              />
              <.input
                field={@report_form[:payer_phone_number]}
                type="text"
                label="Teléfono del titular (si aplica)"
              />
              <.input
                field={@report_form[:reference_number]}
                type="text"
                label="Referencia de pago"
              />
              <div class="md:col-span-2">
                <button class="btn btn-primary btn-sm">Notificar pago</button>
              </div>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Mis reportes</h2>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Fecha</th>
                    <th>Monto</th>
                    <th>Referencia</th>
                    <th>Estado</th>
                    <th>Observación</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={report <- @payment_reports}>
                    <td>{Calendar.strftime(report.inserted_at, "%d/%m/%Y %H:%M")}</td>
                    <td>${Decimal.round(report.amount, 2) |> Decimal.to_string()}</td>
                    <td>{report.reference_number}</td>
                    <td>{status_label(report.status)}</td>
                    <td>{report.review_note || "—"}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp status_label(:pending), do: "Pendiente"
  defp status_label(:approved), do: "Aprobado"
  defp status_label(:rejected), do: "Rechazado"
  defp status_label(_), do: "—"

  defp sync_channel_with_method(params, methods) do
    case Enum.find(methods, &(to_string(&1.id) == Map.get(params, "payment_method_id"))) do
      %{type: :bank_account} -> Map.put(params, "channel", "bank_transfer")
      %{type: :mobile_payment} -> Map.put(params, "channel", "mobile_payment")
      _ -> params
    end
  end

  defp default_channel_for_methods([%{type: :bank_account} | _]), do: "bank_transfer"
  defp default_channel_for_methods([%{type: :mobile_payment} | _]), do: "mobile_payment"
  defp default_channel_for_methods(_), do: "bank_transfer"
end
