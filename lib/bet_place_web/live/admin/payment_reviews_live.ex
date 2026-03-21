defmodule BetPlaceWeb.Admin.PaymentReviewsLive do
  use BetPlaceWeb, :live_view

  alias BetPlace.{Accounts, Finance}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BetPlace.PubSub, "admin:payment_reports")
    end

    {:ok,
     socket
     |> assign(:payment_reports, Finance.list_payment_reports())
     |> assign(:users, Accounts.list_users())
     |> assign(:selected_report_id, nil)
     |> assign(:show_approve_modal, false)
     |> assign(:show_reject_modal, false)
     |> assign(
       :manual_form,
       to_form(%{"user_id" => "", "amount" => "", "description" => ""}, as: :manual)
     )
     |> assign(
       :approval_form,
       to_form(%{"report_id" => "", "approved_amount" => "", "note" => ""}, as: :approval)
     )
     |> assign(:reject_form, to_form(%{"report_id" => "", "reason" => ""}, as: :reject))}
  end

  def handle_info({:payment_report_created, _report_id}, socket) do
    {:noreply,
     socket
     |> assign(:payment_reports, Finance.list_payment_reports())
     |> put_flash(:info, "Nuevo reporte de pago recibido.")}
  end

  def handle_info({:payment_report_reviewed, _report_id, status}, socket) do
    message =
      case status do
        :approved -> "Una recarga fue aprobada."
        :rejected -> "Un reporte fue rechazado."
        _ -> "Estado de reportes actualizado."
      end

    {:noreply,
     socket
     |> assign(:payment_reports, Finance.list_payment_reports())
     |> put_flash(:info, message)}
  end

  def handle_info({:manual_balance_adjusted, _user_id}, socket) do
    {:noreply,
     socket
     |> assign(:users, Accounts.list_users())
     |> put_flash(:info, "Se aplicó un ajuste de saldo manual.")}
  end

  def handle_event("open_approve_modal", %{"id" => report_id}, socket) do
    report = Enum.find(socket.assigns.payment_reports, &(&1.id == report_id))

    {:noreply,
     socket
     |> assign(:selected_report_id, report_id)
     |> assign(:show_approve_modal, true)
     |> assign(
       :approval_form,
       to_form(%{"report_id" => report_id, "approved_amount" => report.amount, "note" => ""},
         as: :approval
       )
     )}
  end

  def handle_event("open_reject_modal", %{"id" => report_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_report_id, report_id)
     |> assign(:show_reject_modal, true)
     |> assign(:reject_form, to_form(%{"report_id" => report_id, "reason" => ""}, as: :reject))}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, socket |> assign(:show_approve_modal, false) |> assign(:show_reject_modal, false)}
  end

  def handle_event("approve_report", %{"approval" => params}, socket) do
    admin_id = socket.assigns.current_scope.user.id
    amount = Decimal.new(params["approved_amount"])

    case Finance.approve_payment_report(params["report_id"], admin_id, amount, params["note"]) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:payment_reports, Finance.list_payment_reports())
         |> assign(:show_approve_modal, false)
         |> put_flash(:info, "Recarga aprobada y saldo acreditado.")}

      {:error, _step, changeset, _} ->
        {:noreply,
         socket
         |> assign(:approval_form, to_form(changeset, as: :approval))
         |> put_flash(:error, "No se pudo aprobar la recarga.")}
    end
  end

  def handle_event("reject_report", %{"reject" => params}, socket) do
    admin_id = socket.assigns.current_scope.user.id

    case Finance.reject_payment_report(params["report_id"], admin_id, params["reason"]) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:payment_reports, Finance.list_payment_reports())
         |> assign(:show_reject_modal, false)
         |> put_flash(:info, "Reporte rechazado.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :reject_form, to_form(changeset, as: :reject))}
    end
  end

  def handle_event("manual_adjust", %{"manual" => params}, socket) do
    admin_id = socket.assigns.current_scope.user.id
    amount = Decimal.new(params["amount"])

    case Finance.apply_manual_balance_adjustment(
           params["user_id"],
           admin_id,
           amount,
           params["description"]
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:users, Accounts.list_users())
         |> put_flash(:info, "Ajuste manual aplicado.")}

      {:error, _step, _changeset, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo aplicar el ajuste manual.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h1 class="card-title text-2xl">Revisión de recargas</h1>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Usuario</th>
                    <th>Monto</th>
                    <th>Ref.</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={report <- @payment_reports}>
                    <td>{report.user.username}</td>
                    <td>${Decimal.round(report.amount, 2) |> Decimal.to_string()}</td>
                    <td>{report.reference_number}</td>
                    <td>{status_label(report.status)}</td>
                    <td class="flex gap-2">
                      <%= if report.status == :pending do %>
                        <button
                          class="btn btn-success btn-xs"
                          phx-click="open_approve_modal"
                          phx-value-id={report.id}
                        >
                          Aprobar
                        </button>
                        <button
                          class="btn btn-error btn-xs"
                          phx-click="open_reject_modal"
                          phx-value-id={report.id}
                        >
                          Rechazar
                        </button>
                      <% else %>
                        <span class="text-xs text-base-content/60">
                          {report.review_note || "Sin observación"}
                        </span>
                      <% end %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>

        <section :if={@show_approve_modal} class="card bg-base-100 border border-success shadow-sm">
          <div class="card-body">
            <h3 class="card-title">Aprobar recarga</h3>
            <.form
              for={@approval_form}
              id="approve-report-form"
              phx-submit="approve_report"
              class="grid grid-cols-1 md:grid-cols-3 gap-3"
            >
              <.input field={@approval_form[:report_id]} type="hidden" />
              <.input
                field={@approval_form[:approved_amount]}
                type="number"
                step="0.01"
                label="Monto a acreditar"
              />
              <.input field={@approval_form[:note]} type="text" label="Nota (opcional)" />
              <div class="flex items-end gap-2">
                <button class="btn btn-success btn-sm">Confirmar aprobación</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="close_modals">
                  Cancelar
                </button>
              </div>
            </.form>
          </div>
        </section>

        <section :if={@show_reject_modal} class="card bg-base-100 border border-error shadow-sm">
          <div class="card-body">
            <h3 class="card-title">Rechazar recarga</h3>
            <.form
              for={@reject_form}
              id="reject-report-form"
              phx-submit="reject_report"
              class="grid grid-cols-1 md:grid-cols-2 gap-3"
            >
              <.input field={@reject_form[:report_id]} type="hidden" />
              <.input field={@reject_form[:reason]} type="text" label="Motivo del rechazo" />
              <div class="flex items-end gap-2">
                <button class="btn btn-error btn-sm">Confirmar rechazo</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="close_modals">
                  Cancelar
                </button>
              </div>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Ajuste manual de saldo</h2>
            <.form
              for={@manual_form}
              id="manual-balance-form"
              phx-submit="manual_adjust"
              class="grid grid-cols-1 md:grid-cols-4 gap-4"
            >
              <.input
                field={@manual_form[:user_id]}
                type="select"
                label="Usuario"
                options={Enum.map(@users, &{"#{&1.username} (#{&1.email})", &1.id})}
              />
              <.input field={@manual_form[:amount]} type="number" step="0.01" label="Monto (+/-)" />
              <.input field={@manual_form[:description]} type="text" label="Descripción" />
              <div class="flex items-end pt-6">
                <button class="btn btn-primary btn-sm w-full">Aplicar ajuste</button>
              </div>
            </.form>
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
end
