defmodule LoanPayment do
  defstruct [:capital, :interest, payment_no: 0]

  def total(%LoanPayment{} = payment), do: payment.capital + payment.interest
end
