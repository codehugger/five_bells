defmodule MarketAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      supplier: nil,
      name: "Market",
      bid_price: 1,
      sell_price: 2,
      min_spread: 1,
      max_spread: 5,
      spread: 4,
      initial_deposit: 0,
      products_sold: 0,
      products_bought: 0,
      products_sold_total: 0,
      current_cycle: 0,
      max_inventory: -1,
      cash_buffer: 4,
      inventory: []
    ]
  end

  def start_link(args) do
    case Agent.start_link(fn -> struct(State, args) end) do
      {:ok, agent} = resp ->
        case open_deposit_account(agent) do
          :ok -> resp
          err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  def state(agent), do: Agent.get(agent, & &1)
  def name(agent), do: state(agent).name
  def bank(agent), do: state(agent).bank
  def supplier(agent), do: state(agent).supplier
  def inventory(agent), do: state(agent).inventory

  def account_deposit(agent) do
    case BankAgent.get_account_deposit(bank(agent), agent) do
      {:ok, deposit} -> deposit
      err -> err
    end
  end

  def account_delta(agent) do
    case BankAgent.get_account_delta(bank(agent), agent) do
      {:ok, delta} -> delta
      err -> err
    end
  end

  def current_cycle(agent), do: state(agent).current_cycle
  def products_sold(agent), do: state(agent).products_sold
  def products_sold_total(agent), do: state(agent).products_sold_total
  def products_bought(agent), do: state(agent).products_bought
  def inventory_count(agent), do: length(inventory(agent))
  def max_inventory(agent), do: state(agent).max_inventory
  def max_items(agent), do: max(max_inventory(agent) - inventory_count(agent), 3)
  def initial_deposit(agent), do: state(agent).initial_deposit
  def out_of_stock?(agent), do: length(inventory(agent)) <= 0
  def uses_inventory?(agent), do: max_inventory(agent) > 0
  def full?(agent), do: remaining_space(agent) <= 0
  def remaining_space(agent), do: max_inventory(agent) - inventory_count(agent)
  def quantity_available?(agent, quantity), do: inventory_count(agent) - quantity >= 0
  def discard_inventory?(agent), do: !uses_inventory?(agent)
  def sell_price(agent), do: state(agent).sell_price
  def bid_price(agent), do: state(agent).bid_price
  def spread(agent), do: state(agent).spread
  def max_spread(agent), do: max_spread(agent)
  def min_spread(agent), do: min_spread(agent)
  def available_cash(agent), do: account_deposit(agent) - max_inventory(agent) * bid_price(agent)
  def cash_buffer(agent), do: state(agent).cash_buffer
  def deposit_buffer(agent), do: account_deposit(agent) / cash_buffer(agent)

  def set_supplier(agent, supplier) when is_pid(supplier) do
    Agent.update(agent, fn x -> %{x | supplier: supplier} end)
  end

  def set_bank(agent, bank) when is_pid(bank) do
    Agent.update(agent, fn x -> %{x | bank: bank} end)
  end

  def needs_to_restock?(agent) do
    out_of_stock?(agent) && max_inventory(agent) - inventory_count(agent) > 0
  end

  def evaluate(agent, cycle, simulation_id \\ "") do
    # record the state of inventory and prices
    # make the necessary price adjustments
    # adjust spread if necessary
    # reset cycle data
    with :ok <- flush_statistics(agent, cycle, simulation_id),
         :ok <- adjust_prices(agent),
         :ok <- adjust_spread(agent),
         :ok <- acquire_inventory(agent),
         :ok <- reset_cycle(agent, cycle) do
      :ok
    else
      err -> err
    end
  end

  defp reset_cycle(agent, cycle) do
    # discard the inventory if required to do so
    inventory = if discard_inventory?(agent), do: [], else: inventory(agent)

    Agent.update(agent, fn x ->
      %{
        x
        | products_sold: 0,
          current_cycle: cycle,
          inventory: inventory
      }
    end)
  end

  def flush_statistics(agent, cycle, simulation_id) do
    with :ok <- flush_price_statistics(agent, cycle, simulation_id),
         :ok <- flush_inventory_statistics(agent, cycle, simulation_id) do
      :ok
    else
      err -> err
    end
  end

  def flush_price_statistics(agent, cycle, simulation_id) do
    market = state(agent)

    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.sell_price.#{market.name}",
               market.sell_price,
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.bid_price.#{market.name}",
               market.bid_price,
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.spread.#{market.name}",
               spread(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  def flush_inventory_statistics(agent, cycle, simulation_id) do
    market = state(agent)

    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.products_sold.#{market.name}",
               products_sold(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.products_sold_total.#{market.name}",
               products_sold_total(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.products_bought.#{market.name}",
               products_bought(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "market.inventory_count.#{market.name}",
               inventory_count(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  defp create_time_series_entry(label, value, cycle, simulation_id) do
    %Repo.TimeSeries{label: label, value: value, cycle: cycle, simulation_id: simulation_id}
  end

  def sell_to_customer(agent, customer, quantity \\ 1) when is_pid(customer) do
    with :ok <- acquire_inventory(agent, quantity),
         {:ok, _product} = result <- sell_products(agent, customer, quantity) do
      result
    else
      err -> err
    end
  end

  def price_to_customer(_agent), do: 1

  def acquire_inventory(agent), do: acquire_inventory(agent, max_items(agent))

  def acquire_inventory(agent, quantity) do
    case supplier(agent) do
      nil ->
        {:error, :no_supplier}

      supplier ->
        case needs_to_restock?(agent) || uses_inventory?(agent) == false do
          true ->
            with {:ok, products} <-
                   FactoryAgent.sell_to_customer(supplier, agent, quantity),
                 :ok <- add_to_inventory(agent, products) do
              :ok
            else
              err -> err
            end

          false ->
            :ok
        end
    end
  end

  def inventory_delta(agent), do: products_bought(agent) - products_sold(agent)
  def inventory_growing?(agent), do: inventory_delta(agent) > 0
  def inventory_shrinking?(agent), do: inventory_delta(agent) < 0
  def inventory_unchanged?(agent), do: inventory_delta(agent) == 0

  #############################################################################
  # Private
  #############################################################################

  defp sell_products(agent, customer, quantity) do
    case quantity_available?(agent, quantity) do
      false ->
        {:error, {:not_enough_stock, [available: inventory_count(agent), requested: quantity]}}

      true ->
        case BankAgent.transfer(bank(agent), customer, agent, quantity) do
          :ok ->
            case remove_from_inventory(agent, quantity) do
              {:ok, products} = result ->
                Agent.update(agent, fn x ->
                  %{
                    x
                    | products_sold: x.products_sold + length(products),
                      products_sold_total: x.products_sold_total + length(products)
                  }
                end)

                result

              err ->
                err
            end

          err ->
            err
        end
    end
  end

  defp remove_from_inventory(agent, quantity) do
    case length(inventory(agent)) >= quantity do
      true ->
        {outgoing, remaining} = Enum.split(inventory(agent), quantity)
        {Agent.update(agent, fn x -> %{x | inventory: remaining} end), outgoing}

      false ->
        {:error, :out_of_stock}
    end
  end

  defp add_to_inventory(agent, products) do
    case remaining_space(agent) >= length(products) || uses_inventory?(agent) == false do
      false -> {:error, :not_enough_space}
      true -> Agent.update(agent, fn x -> %{x | inventory: x.inventory ++ products} end)
    end
  end

  defp adjust_prices(agent) do
    cond do
      # inventory is growing lower prices
      inventory_growing?(agent) ->
        lower_prices(agent)

      # inventory is shrinking raise prices
      inventory_shrinking?(agent) ->
        raise_prices(agent)

      # inventory is unchanged ... take special measures
      inventory_unchanged?(agent) ->
        cond do
          # since we are probably unable to acquire inventory
          # we raise the price in an attempt to seduce a provider
          inventory_count(agent) == 0 -> raise_prices(agent)
          # we have inventory but nothing is happening to it so
          # lower prices in an attempt to get rid of some of it
          true -> lower_prices(agent)
        end
    end
  end

  defp adjust_spread(agent) do
    cond do
      account_delta(agent) < 0 -> increase_spread(agent, 1)
      true -> :ok
    end
  end

  defp raise_prices(agent, amount \\ 1) when amount >= 1 do
    case available_cash(agent) < deposit_buffer(agent) do
      true ->
        {:error, :prices_at_maximum}

      false ->
        Agent.update(agent, fn x ->
          %{x | bid_price: x.bid_price + amount, sell_price: x.sell_price + amount}
        end)
    end
  end

  defp lower_prices(agent, amount \\ 1) when amount >= 1 do
    case bid_price(agent) - amount < 1 do
      true ->
        {:error, :prices_at_minimum}

      false ->
        Agent.update(agent, fn x ->
          %{x | bid_price: x.bid_price - amount, sell_price: x.sell_price - amount}
        end)
    end
  end

  def increase_spread(agent, amount) do
    Agent.update(agent, fn x ->
      spread = min(x.max_spread, x.spread + amount)
      %{x | spread: spread, sell_price: x.bid_price * spread}
    end)
  end

  defp decrease_spread(agent, amount) do
    Agent.update(agent, fn x ->
      spread = max(x.min_spread, x.spread - amount)
      %{x | spread: spread, sell_price: x.bid_price * spread}
    end)
  end

  defp open_deposit_account(agent) do
    cond do
      bank(agent) != nil ->
        case BankAgent.open_deposit_account(bank(agent), agent, initial_deposit(agent)) do
          {:ok, account_no} -> Agent.update(agent, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
    end
  end
end
