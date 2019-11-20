# defmodule MarketAgent do
#   use Agent

#   defmodule State do
#     defstruct [
#       :name,
#       :bank,
#       :supplier,
#       cash_buffer: 4,
#       max_inventory: 20,
#       employees: [],
#       current_cycle: 0,
#       salaries_paid: %Stats{},
#       inventory_size: %Stats{},
#       inventory: []
#     ]
#   end

#   def start_link(name, bank, supplier, properties = %State{}) do
#     Agent.start_link(fn -> %State{properties | name: name, bank: bank, supplier: supplier} end)
#   end

#   def state(agent), do: Agent.get(agent, & &1)
#   def inventory_size(agent), do: length(state(agent).inventory)
#   def full?(agent), do: inventory_size(agent) < state(agent).max_inventory

#   def evaluate(agent, cycle) do
#     case cycle == state(agent).current_cycle do
#       true ->
#         {:error, :cycle_already_run}

#       false ->
#         buy_products(agent)
#         pay_salaries(agent)
#         adjust_prices(agent)
#         record_stats(agent)
#     end
#   end

#   def buy_products(agent) do
#     case state(agent).init_purchase do
#       true ->
#         case full?(agent) do
#           false -> state(agent).supplier.buy()
#           true -> increase_spread(agent)
#         end
#     end
#   end

#   def pay_salaries(agent) do
#     {employees_paid, amount_paid} =
#       Enum.map_reduce(state(agent).employees, 0, fn employee, acc ->
#         salary = EmployeeAgent.salary(employee)

#         case BankAgent.get_account_deposit(state(agent).bank, agent) > salary do
#           true ->
#             BankAgent.transfer(state(agent).bank, agent, employee, salary)
#             {employee, acc + salary}

#           false ->
#             {nil, acc}
#         end
#       end)

#     Agent.update(agent, fn _ ->
#       %{
#         state(agent)
#         | employees: Enum.filter(employees_paid, &(!is_nil(&1))),
#           salaries_paid: Stats.add_value(state(agent).salaries_paid, amount_paid)
#       }
#     end)
#   end

#   def adjust_prices(agent) do
#     cond do
#       inventory_growing?(agent) ->
#         adjust_prices(agent, -1)

#       inventory_shrinking?(agent) ->
#         adjust_prices(agent, +1)

#       inventory_unchanged?(agent) ->
#         adjust_prices(agent, 1)
#     end
#   end

#   def adjust_prices(agent, amount) do
#     state = state(agent)

#     cond do
#       available_cash(agent) / state.cash_buffer && amount >= 1 -> false
#       true -> true
#     end
#   end

#   def record_stats(agent) do
#   end

#   def max_lot(agent) do
#     case full?(agent) do
#       true -> 0
#       false -> nil
#     end
#   end

#   def max_items(agent) do
#     state = state(agent)

#     cond do
#       state.max_inventory == 0 -> get_deposit(agent) / state.bid_price
#       true -> state.max_inventory - inventory.get_total_itmes
#     end
#   end

#   def increase_spread(agent, amount \\ 1) do
#     with state <- state(agent),
#          true <- state.spread + amount < state.max_spread do
#       Agent.update(agent, fn _ -> %{state | spread: state.spread + amount} end)
#     end
#   end

#   def available_cash(agent) do
#     state = state(agent)

#     case BankAgent.get_account(state.bank, agent) do
#       {:ok, account} -> account.deposit - max_items(agent) * state.bid_price
#     end
#   end

#   def get_deposit(agent) do
#     case BankAgent.get_account(state(agent).bank, agent) do
#       {:ok, account} -> account.deposit
#       err -> err
#     end
#   end

#   def inventory_shrinking?(agent) do
#     length(state(agent).inventory) < state(agent).inventory_size
#   end

#   def inventory_growing?(agent) do
#     length(state(agent).inventory) > state(agent).inventory_size
#   end

#   def inventory_unchanged?(agent) do
#     length(state(agent).inventory) == state(agent).inventory_size
#   end
# end
