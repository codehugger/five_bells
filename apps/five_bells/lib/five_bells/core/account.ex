defmodule Account do
  defstruct [:account_no, :owner_type, :owner_id, deposit: 0, delta: 0]
end
