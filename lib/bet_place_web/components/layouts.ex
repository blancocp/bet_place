defmodule BetPlaceWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use BetPlaceWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar bg-base-100 border-b border-base-200 px-4 sm:px-6 lg:px-8 sticky top-0 z-50">
      <div class="flex-1">
        <.link navigate={~p"/"} class="flex items-center gap-2 font-bold text-lg">
          🐎 Bet Place
        </.link>
      </div>
      <div class="flex-none gap-2">
        <%= if @current_scope do %>
          <%= if BetPlace.Accounts.Scope.admin?(@current_scope) do %>
            <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">
              Admin
            </.link>
          <% end %>
          <.link navigate={~p"/eventos"} class="btn btn-ghost btn-sm">
            Eventos
          </.link>
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1">
              <.icon name="hero-user-circle" class="size-5" />
              {@current_scope.user.username}
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu bg-base-100 rounded-box z-10 w-48 p-2 shadow border border-base-200"
            >
              <li class="menu-title text-xs">{@current_scope.user.email}</li>
              <li class="px-3 py-2">
                <div class="flex items-center justify-between gap-2 pointer-events-none">
                  <span class="text-xs text-base-content/50">Saldo</span>
                  <span class="font-mono font-bold text-sm text-success">
                    ${Decimal.round(@current_scope.user.balance, 2) |> Decimal.to_string()}
                  </span>
                </div>
              </li>
              <div class="divider my-0"></div>
              <li>
                <.link href={~p"/logout"} method="delete" class="text-error">
                  <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Cerrar sesión
                </.link>
              </li>
            </ul>
          </div>
        <% else %>
          <.link navigate={~p"/login"} class="btn btn-ghost btn-sm">Ingresar</.link>
          <.link navigate={~p"/register"} class="btn btn-primary btn-sm">Registrarse</.link>
        <% end %>
        <.theme_toggle />
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
