defmodule BetPlaceWeb.Router do
  use BetPlaceWeb, :router

  import BetPlaceWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BetPlaceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  pipeline :require_admin_role do
    plug :require_admin
  end

  # ── Guest-only routes (redirect if already logged in) ─────────────────────
  scope "/", BetPlaceWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    live_session :redirect_if_authenticated,
      on_mount: [{BetPlaceWeb.UserAuth, :mount_current_scope}] do
      live "/login", UserLoginLive, :new
      live "/register", UserRegistrationLive, :new
    end

    post "/login", UserSessionController, :create
  end

  # ── Public routes (logged in or not) ─────────────────────────────────────
  scope "/", BetPlaceWeb do
    pipe_through :browser

    delete "/logout", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{BetPlaceWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive
    end
  end

  # ── Authenticated bettor routes ───────────────────────────────────────────
  scope "/", BetPlaceWeb do
    pipe_through [:browser, :require_auth]

    live_session :authenticated,
      on_mount: [{BetPlaceWeb.UserAuth, :require_authenticated_user}] do
      live "/eventos", Bettor.GameEventListLive
      live "/eventos/:id", Bettor.GameEventShowLive
      live "/mis-tickets", Bettor.MyTicketsLive
      live "/historial", Bettor.BettingHistoryLive
    end
  end

  # ── Admin routes ──────────────────────────────────────────────────────────
  scope "/admin", BetPlaceWeb.Admin do
    pipe_through [:browser, :require_admin_role]

    live_session :admin,
      on_mount: [{BetPlaceWeb.UserAuth, :require_admin}] do
      live "/", DashboardLive
      live "/eventos", GameEventListLive
      live "/eventos/nuevo", GameEventNewLive
      live "/eventos/:id", GameEventShowLive
      live "/eventos/:event_id/matchups/nuevo", HvhMatchupNewLive
      live "/usuarios", UserListLive
      live "/tickets", TicketsLive
      live "/api-usage", ApiUsageLive
    end
  end

  # ── Dev tools ─────────────────────────────────────────────────────────────
  if Application.compile_env(:bet_place, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BetPlaceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
