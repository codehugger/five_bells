import Config

config :five_bells, FiveBells.Repo,
  database: "five_bells_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :five_bells, ecto_repos: [FiveBells.Repo]

config :logger, level: :info
