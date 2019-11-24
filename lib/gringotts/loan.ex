defmodule Loan do
  defstruct principal: 0,
            interest_rate: 0.0,
            duration: 1,
            period: 1,
            scheduled_payments: [],
            payments_made: [],
            payments_remaining: []

  def paid_off?(%Loan{} = loan) do
    length(loan.payments_remaining) == 0
  end

  def calculate_payments(%Loan{} = loan) do
    %Loan{
      loan
      | payments_made: [],
        payments_remaining:
          Enum.map(1..loan.duration, fn _ ->
            %LoanPayment{capital: loan.principal / loan.duration, interest: 0}
          end)
    }
    |> add_baloon_payment()
  end

  def next_payment(%Loan{} = loan) do
    case loan.payments_remaining do
      [] -> nil
      [next] -> next
      [next | _] -> next
    end
  end

  def make_payment(%Loan{} = loan) do
    case next_payment(loan) do
      nil ->
        {:error, :loan_paid_off}

      payment ->
        {:ok,
         %Loan{
           loan
           | payments_made: [payment | loan.payments_made],
             payments_remaining: Enum.reject(loan.payments_remaining, fn x -> x == payment end)
         }}
    end
  end

  defp add_baloon_payment(%Loan{} = loan) do
    _capital_sum = Enum.reduce(loan.payments_remaining, 0, fn x, acc -> acc + x.capital end)
    loan
  end
end
