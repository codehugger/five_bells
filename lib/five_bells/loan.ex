defmodule Loan do
  defstruct principal: 0,
            interest_rate: 0.0,
            duration: 12,
            period: 1,
            scheduled_payments: [],
            payments_made: [],
            payments_remaining: []

  def paid_off?(%Loan{} = loan), do: length(loan.payments_remaining) == 0
  def monthly_rate(%Loan{} = loan), do: loan.interest_rate * 0.01 / 12.0
  def no_payments(%Loan{} = loan), do: round(loan.duration / loan.period)

  def monthly_payment(%Loan{} = loan) do
    monthly_rate = Loan.monthly_rate(loan)

    case monthly_rate == 0 do
      true ->
        loan.principal / no_payments(loan)

      false ->
        loan.principal * monthly_rate /
          (1.0 - 1.0 / :math.pow(1.0 + monthly_rate, loan.duration))
    end
  end

  def calculate_payments(%Loan{} = loan) do
    {payments, _} =
      Enum.map_reduce(1..no_payments(loan), loan.principal, fn payment_no, remains ->
        interest_payment = round(:math.floor(remains * monthly_rate(loan)))
        capital_payment = round(monthly_payment(loan) - interest_payment)

        {%LoanPayment{
           payment_no: payment_no,
           capital: capital_payment,
           interest: interest_payment
         }, remains - capital_payment}
      end)

    %Loan{
      loan
      | payments_made: [],
        payments_remaining: payments
    }
    |> add_baloon_payment()
  end

  def next_payment(%Loan{} = loan) do
    case loan.payments_remaining do
      [] -> {:error, :loan_paid_off}
      [next | _] -> {:ok, next}
    end
  end

  def make_payment(%Loan{} = loan) do
    case next_payment(loan) do
      {:ok, payment} ->
        {:ok,
         %Loan{
           loan
           | payments_made: [payment | loan.payments_made],
             payments_remaining: Enum.reject(loan.payments_remaining, fn x -> x == payment end)
         }}

      err ->
        err
    end
  end

  defp add_baloon_payment(%Loan{} = loan) do
    capital_sum = Enum.reduce(loan.payments_remaining, 0, fn x, acc -> acc + x.capital end)
    [last | tail] = Enum.reverse(loan.payments_remaining)

    %Loan{
      loan
      | payments_remaining:
          Enum.reverse([
            %LoanPayment{last | capital: last.capital + (loan.principal - capital_sum)}
            | tail
          ])
    }
  end
end
