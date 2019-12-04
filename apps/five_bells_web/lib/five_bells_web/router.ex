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

    get("/", SimulationController, :index)
    get("/:id", SimulationController, :show)
    get("/:simulation_id/entities/:entity_id", EntityController, :show)
    get("/:simulation_id/banks/:bank_id", BankController, :show)
  end

  # Other scopes may use custom stacks.
  # scope "/api", FiveBellsWeb do
  #   pipe_through :api
  # end
end
