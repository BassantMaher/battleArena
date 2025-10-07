defmodule TapGame.Repo do
  use Ecto.Repo,
    otp_app: :tap_game,
    adapter: Ecto.Adapters.Postgres
end
