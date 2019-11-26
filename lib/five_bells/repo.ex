defmodule FiveBells.Repo do
  use Ecto.Repo,
    otp_app: :five_bells,
    adapter: Ecto.Adapters.Postgres
end
