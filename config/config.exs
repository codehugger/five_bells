# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of Mix.Config.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
use Mix.Config

# Configure Mix tasks and generators
config :five_bells,
  ecto_repos: [FiveBells.Repo]

config :five_bells_web,
  ecto_repos: [FiveBells.Repo],
  generators: [context_app: :five_bells]

# Configures the endpoint
config :five_bells_web, FiveBellsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6G+wIYitxUrlYl98paZZOpsANn4hfB7/2kJ01YDEaL4boNk+4qGBjrhoVJXF/Jl2",
  render_errors: [view: FiveBellsWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: FiveBellsWeb.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
