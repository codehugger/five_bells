defmodule FiveBells.Agents.MarketAgent do
  use Agent
  require Logger

  alias FiveBells.Agents.{BankAgent, FactoryAgent}

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      supplier: nil,
      name: "Market",
      market_no: "M-0001",
      bid_price: 1,
      bid_prices: [],
      sell_price: 2,
      sell_prices: [],
      min_spread: 1,
      max_spread: 4,
      spread: 4,
      spreads: [],
      initial_deposit: 0,
      products_sold: 0,
      products_sold_total: 0,
      products_bought: 0,
      products_bought_total: 0,
      current_cycle: 0,
      max_inventory: -1,
      cash_buffer: 4,
      inventory: [],
      initiates_purchase: false
    ]
  end

  def state(agent), do: Agent.get(agent, & &1)

  #############################################################################
  # Simulation
  #############################################################################

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

  def stop(agent), do: Agent.stop(agent)

  def current_cycle(agent), do: state(agent).current_cycle

  def evaluate(agent, cycle, simulation_id \\ "") do
    # make the necessary price adjustments
    # adjust spread if necessary
    # record the state of inventory and prices
    # reset cycle data
    with :ok <- adjust_spread(agent),
         :ok <- adjust_prices(agent),
         :ok <- purchase_inventory(agent),
         # :ok <- pay_salaries(agent, cycle, simulation_id),
         # :ok <- hire_fire_employees(agent, cycle, simulation_id),
         :ok <- flush_statistics(agent, cycle, simulation_id),
         :ok <- reset_cycle(agent, cycle) do
      :ok
    else
      err ->
        Logger.error("Market is having problems: #{inspect(err)}")
        err
    end
  end

  #############################################################################
  # Funds
  #############################################################################

  def bank(agent), do: state(agent).bank
  def initial_deposit(agent), do: state(agent).initial_deposit
  def available_cash(agent), do: account_deposit(agent) - max_inventory(agent) * bid_price(agent)
  def cash_buffer(agent), do: state(agent).cash_buffer
  def deposit_buffer(agent), do: round(account_deposit(agent) / cash_buffer(agent))

  def account(agent) do
    case BankAgent.get_account(bank(agent), agent) do
      {:ok, account} -> account
      err -> err
    end
  end

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

  def set_bank(agent, bank) when is_pid(bank) do
    Agent.update(agent, fn x -> %{x | bank: bank} end)
  end

  #############################################################################
  # Sales / Customer
  #############################################################################

  def sell_to_customer(agent, customer, quantity \\ 1, price \\ -1) when is_pid(customer) do
    # the main things to consider here are
    # 1. do we have the requested quantity
    # 2. are we willing to go and buy to meet the quantity requirement
    with {:ok, _products} = result <- sell_products(agent, customer, quantity, price) do
      result
    else
      err -> err
    end
  end

  defp sell_products(agent, customer, quantity, price) do
    # the things to consider here are
    # 1. do we have the given quantity in inventory
    # 2. did the transfer from the customer go through?
    # 3. were we able to hand over the requsted products?
    sales_price =
      case price do
        -1 -> sell_price(agent)
        _ -> price
      end

    case quantity_available?(agent, quantity) do
      false ->
        {:error, {:not_enough_stock, [available: inventory_count(agent), requested: quantity]}}

      true ->
        case BankAgent.transfer(
               bank(agent),
               customer,
               agent,
               quantity * sales_price,
               "Product purchase"
             ) do
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
                BankAgent.transfer(
                  customer,
                  bank(agent),
                  agent,
                  quantity * sales_price,
                  "Refund product purchase"
                )

                err
            end

          err ->
            err
        end
    end
  end

  #############################################################################
  # Purchase / Supplier
  #############################################################################

  def product_name(agent), do: FactoryAgent.product_name(state(agent).supplier)

  def supplier(agent), do: state(agent).supplier

  def set_supplier(agent, supplier) when is_pid(supplier) do
    Agent.update(agent, fn x -> %{x | supplier: supplier} end)
  end

  def initiates_purchase?(agent), do: state(agent).initiates_purchase

  defp purchase_inventory(agent), do: purchase_inventory(agent, purchase_capacity(agent))

  defp purchase_inventory(agent, quantity) do
    # things to consider
    # 1. do we need to restock? (do we keep an inventory?)
    # 2. do we have a supplier?
    case needs_to_restock?(agent) do
      true ->
        IO.puts("#{state(agent).name} purchasing inventory")

        case supplier(agent) do
          nil -> {:error, :no_supplier}
          supplier -> FactoryAgent.sell_to_customer(supplier, agent, quantity)
        end

      false ->
        :ok
    end
  end

  def receive_delivery(agent, products) do
    IO.puts("#{state(agent).name} receiving inventory of size #{length(products)}")

    case add_to_inventory(agent, products) do
      :ok -> :ok
      err -> err
    end
  end

  def purchase_capacity(agent) do
    # here there are two main things to consider
    # 1. how many do we want and have storage for?
    # 2. how many can we afford?
    case inventory_count(agent) < max_inventory(agent) do
      true ->
        min(max_items(agent), round(available_cash(agent) / bid_price(agent)))

      false ->
        0
    end
  end

  #############################################################################
  # Inventory
  #############################################################################

  def available_quantity?(agent, quantity) do
    case inventory_count(agent) >= quantity do
      true -> {:ok, inventory_count(agent)}
      false -> {:error, :quantity_unavailable}
    end
  end

  def needs_to_restock?(agent) do
    # here we need to consider the following
    # 1. do we keep an inventory at all?
    # 2. do we initiate purchases or do we wait for the supplier?
    # 3. are we out of stock?
    # 4. can we afford to buy more stock?
    case uses_inventory?(agent) && initiates_purchase?(agent) do
      true -> out_of_stock?(agent) && max_items(agent) > 0
      false -> false
    end
  end

  defp open_deposit_account(agent) do
    cond do
      bank(agent) != nil ->
        case BankAgent.open_deposit_account(
               bank(agent),
               agent,
               "Market",
               state(agent).market_no,
               initial_deposit(agent)
             ) do
          {:ok, account_no} -> Agent.update(agent, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
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
      false ->
        {:error, :not_enough_space}

      true ->
        Agent.update(agent, fn x ->
          %{
            x
            | inventory: x.inventory ++ products,
              products_bought: x.products_bought + length(products),
              products_bought_total: x.products_bought_total + length(products)
          }
        end)
    end
  end

  defp inventory_count(agent), do: length(inventory(agent))
  defp max_inventory(agent), do: state(agent).max_inventory
  defp max_items(agent), do: max_inventory(agent) - inventory_count(agent)
  defp inventory(agent), do: state(agent).inventory
  defp inventory_delta(agent), do: products_bought(agent) - products_sold(agent)
  defp inventory_growing?(agent), do: inventory_delta(agent) > 0
  defp inventory_shrinking?(agent), do: inventory_delta(agent) < 0
  defp inventory_unchanged?(agent), do: inventory_delta(agent) == 0
  defp out_of_stock?(agent), do: length(inventory(agent)) <= 0
  defp uses_inventory?(agent), do: max_inventory(agent) > 0
  defp remaining_space(agent), do: max_inventory(agent) - inventory_count(agent)
  defp quantity_available?(agent, quantity), do: inventory_count(agent) - quantity >= 0
  defp discard_inventory?(agent), do: !uses_inventory?(agent)

  #############################################################################
  # Price / Spread
  #############################################################################

  def sell_price(agent), do: state(agent).sell_price
  def bid_price(agent), do: state(agent).bid_price
  defp spread(agent), do: state(agent).spread

  defp adjust_prices(agent) do
    cond do
      state(agent).max_spread == 1 ->
        :ok

      # inventory is growing lower prices
      inventory_growing?(agent) ->
        lower_prices(agent)

      # inventory is shrinking raise prices
      inventory_shrinking?(agent) ->
        raise_prices(agent)

      # inventory is unchanged ... take special measures
      inventory_unchanged?(agent) ->
        IO.puts("Inventory unchanged #{products_bought(agent)}/#{products_sold(agent)}")

        cond do
          # since we are probably unable to acquire inventory
          # we raise the price in an attempt to seduce a provider
          products_bought(agent) > 0 && products_sold(agent) > 0 -> raise_prices(agent)
          # we have inventory but nothing is happening to it so
          # lower prices in an attempt to get rid of some of it
          true -> lower_prices(agent)
        end

        Agent.update(agent, fn x ->
          %{
            x
            | bid_prices: x.bid_prices ++ [x.bid_price],
              sell_prices: x.sell_prices ++ [x.sell_price]
          }
        end)
    end
  end

  defp adjust_spread(agent) do
    IO.puts("#{state(agent).name} adjusting spread")

    cond do
      state(agent).max_spread == 1 -> :ok
      account_delta(agent) > 0 -> increase_spread(agent, 1)
      account_delta(agent) == 0 -> decrease_spread(agent, 1)
      true -> :ok
    end

    Agent.update(agent, fn x ->
      %{
        x
        | spreads: x.spreads ++ [x.spread]
      }
    end)
  end

  defp raise_prices(agent, amount \\ 1) when amount >= 1 do
    # when raising prices we have to be careful to never go above the limit at which we can buy
    cond do
      available_cash(agent) > deposit_buffer(agent) ->
        IO.puts("#{state(agent).name} raising prices")

        bid_price = state(agent).bid_price + amount

        # we maintain the spread but we make sure we always have profits
        # ... this might be too much of an assumption to make
        sell_price = max(bid_price * state(agent).spread, bid_price + 1)

        Agent.update(agent, fn x ->
          %{x | bid_price: bid_price, sell_price: sell_price}
        end)

      true ->
        :ok
    end
  end

  defp lower_prices(agent, amount \\ 1) when amount >= 1 do
    IO.puts("#{state(agent).name} lowering prices")

    bid_price = max(state(agent).bid_price - amount, 1)

    # we maintain the spread but we make sure we always have profits
    # ... this might be too much of an assumption to make
    sell_price = max(bid_price * state(agent).spread, bid_price + 1)

    Agent.update(agent, fn x ->
      %{x | bid_price: bid_price, sell_price: sell_price}
    end)
  end

  defp increase_spread(agent, amount) do
    Agent.update(agent, fn x ->
      spread = min(x.max_spread, x.spread + amount)
      %{x | spread: spread}
    end)
  end

  defp decrease_spread(agent, amount) do
    Agent.update(agent, fn x ->
      spread = max(x.min_spread, x.spread - amount)
      %{x | spread: spread}
    end)
  end

  #############################################################################
  # STATISTICS
  #############################################################################

  def products_sold(agent), do: state(agent).products_sold
  def products_sold_total(agent), do: state(agent).products_sold_total
  def products_bought(agent), do: state(agent).products_bought
  def products_bought_total(agent), do: state(agent).products_bought_total

  defp reset_cycle(agent, cycle) do
    # discard the inventory if required to do so
    inventory = if discard_inventory?(agent), do: [], else: inventory(agent)

    Agent.update(agent, fn x ->
      %{
        x
        | products_sold: 0,
          products_bought: 0,
          current_cycle: cycle,
          inventory: inventory
      }
    end)
  end

  defp flush_statistics(agent, cycle, simulation_id) do
    with :ok <- flush_price_statistics(agent, cycle, simulation_id),
         :ok <- flush_inventory_statistics(agent, cycle, simulation_id),
         :ok <- flush_account_status(agent, cycle, simulation_id) do
      :ok
    else
      err -> err
    end
  end

  defp flush_price_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.sell_price",
               sell_price(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.bid_price",
               bid_price(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.spread",
               spread(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.avg_spread",
               round(Enum.sum(state(agent).spreads) / max(length(state(agent).spreads), 1)),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.avg_bid_price",
               round(Enum.sum(state(agent).bid_prices) / max(length(state(agent).bid_prices), 1)),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.avg_sell_price",
               round(
                 Enum.sum(state(agent).sell_prices) / max(length(state(agent).sell_prices), 1)
               ),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  defp flush_inventory_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.products_sold",
               products_sold(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.products_sold_total",
               products_sold_total(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.products_bought",
               products_bought(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.products_bought_total",
               products_bought_total(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "market.inventory_count",
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

  def flush_account_status(agent, cycle, simulation_id) do
    account = account(agent)

    case FiveBells.Repo.insert(%FiveBells.Banks.Deposit{
           bank_no: BankAgent.state(bank(agent)).bank_no,
           account_no: account.account_no,
           owner_type: "Market",
           owner_id: state(agent).market_no,
           deposit: account.deposit,
           delta: account.delta,
           cycle: cycle,
           simulation_id: simulation_id
         }) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  defp create_time_series_entry(agent, label, value, cycle, simulation_id) do
    market = state(agent)

    %FiveBells.Statistics.TimeSeries{
      entity_type: "Market",
      entity_id: "#{market.market_no}",
      label: label,
      key: "#{market.market_no}",
      value: value,
      cycle: cycle,
      simulation_id: simulation_id
    }
  end
end
