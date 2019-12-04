defmodule Transaction do
  defstruct [
    :bank_no,
    :deb_no,
    :deb_owner_type,
    :deb_owner_id,
    :cred_no,
    :deb_owner_id,
    :cred_owner_id,
    :amount,
    :text
  ]
end
