# Non-agent version

# {:ok, bank} = %Bank{} |> Bank.init_customer_bank_ledgers()
# {:ok, bank, account_no} = Bank.open_deposit_account(bank)

# bank =
#   Enum.reduce(1..10, bank, fn cycle, b ->
#     IO.puts("Running loan cycle: #{cycle}")
#     {:ok, b} = Bank.request_loan(b, account_no, 100)
#     {:ok, b} = Bank.pay_loan(b, account_no)
#     b
#   end)

# IO.inspect(bank)

# Agent simulation

{:ok, bank} = BankAgent.start_link()
{:ok, borrower} = BorrowerAgent.start_link(bank: bank, loan_amount: 10)

BorrowerAgent.evaluate(borrower, 0)
BorrowerAgent.evaluate(borrower, 0)

IO.inspect(BankAgent.state(bank))
