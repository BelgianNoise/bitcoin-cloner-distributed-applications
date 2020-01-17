use Mix.Config

config :assignment,
  from: (DateTime.utc_now() |> DateTime.to_unix()) - 60 * 60 * 24 * 0.3,
  until: (DateTime.utc_now() |> DateTime.to_unix()),
  rate: 5
