defmodule Transaction do
  defstruct [
    :bank_no,
    :deb_no,
    :cred_no,
    :amount,
    :text
  ]
end
