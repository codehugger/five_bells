defmodule FiveBellsWeb.Router do
  use FiveBellsWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", FiveBellsWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/simulations", SimulationController, :index)
    get("/simulations/:id", SimulationController, :show)
    get("/simulations/:simulation_id/entities/:entity_id", EntityController, :show)
  end

  # Other scopes may use custom stacks.
  # scope "/api", FiveBellsWeb do
  #   pipe_through :api
  # end
end
