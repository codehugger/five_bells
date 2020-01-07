# FiveBells.Umbrella

## Installation

* Install the latest version of PostgreSQL
* Install the latest version of Elixir

## Elixir Dependencies

* Run `mix deps.get`

## Configuration

Edit `dev.exs` in the config folder according to your Postgres configuration.

## Ecto Database

cd into the `apps/five_bells/` folder and run 

* `mix ecto.create`
* `mix ecto.migrate`

## Phoenix Web UI

cd into the root folder and run

`mix phx.server`

## Running simulations

cd into root folder and run `mix run /apps/five_bells/prive/examples/name_of_simulation.exs`
