defmodule FiveBells.BanksTest do
  use FiveBells.DataCase

  alias FiveBells.Banks

  describe "transactions" do
    alias FiveBells.Banks.Transaction

    @valid_attrs %{amount: 42, bank: "some bank", cred_no: "some cred_no", cycle: 42, deb_no: "some deb_no", simulation_id: "some simulation_id", text: "some text"}
    @update_attrs %{amount: 43, bank: "some updated bank", cred_no: "some updated cred_no", cycle: 43, deb_no: "some updated deb_no", simulation_id: "some updated simulation_id", text: "some updated text"}
    @invalid_attrs %{amount: nil, bank: nil, cred_no: nil, cycle: nil, deb_no: nil, simulation_id: nil, text: nil}

    def transaction_fixture(attrs \\ %{}) do
      {:ok, transaction} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Banks.create_transaction()

      transaction
    end

    test "list_transactions/0 returns all transactions" do
      transaction = transaction_fixture()
      assert Banks.list_transactions() == [transaction]
    end

    test "get_transaction!/1 returns the transaction with given id" do
      transaction = transaction_fixture()
      assert Banks.get_transaction!(transaction.id) == transaction
    end

    test "create_transaction/1 with valid data creates a transaction" do
      assert {:ok, %Transaction{} = transaction} = Banks.create_transaction(@valid_attrs)
      assert transaction.amount == 42
      assert transaction.bank == "some bank"
      assert transaction.cred_no == "some cred_no"
      assert transaction.cycle == 42
      assert transaction.deb_no == "some deb_no"
      assert transaction.simulation_id == "some simulation_id"
      assert transaction.text == "some text"
    end

    test "create_transaction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Banks.create_transaction(@invalid_attrs)
    end

    test "update_transaction/2 with valid data updates the transaction" do
      transaction = transaction_fixture()
      assert {:ok, %Transaction{} = transaction} = Banks.update_transaction(transaction, @update_attrs)
      assert transaction.amount == 43
      assert transaction.bank == "some updated bank"
      assert transaction.cred_no == "some updated cred_no"
      assert transaction.cycle == 43
      assert transaction.deb_no == "some updated deb_no"
      assert transaction.simulation_id == "some updated simulation_id"
      assert transaction.text == "some updated text"
    end

    test "update_transaction/2 with invalid data returns error changeset" do
      transaction = transaction_fixture()
      assert {:error, %Ecto.Changeset{}} = Banks.update_transaction(transaction, @invalid_attrs)
      assert transaction == Banks.get_transaction!(transaction.id)
    end

    test "delete_transaction/1 deletes the transaction" do
      transaction = transaction_fixture()
      assert {:ok, %Transaction{}} = Banks.delete_transaction(transaction)
      assert_raise Ecto.NoResultsError, fn -> Banks.get_transaction!(transaction.id) end
    end

    test "change_transaction/1 returns a transaction changeset" do
      transaction = transaction_fixture()
      assert %Ecto.Changeset{} = Banks.change_transaction(transaction)
    end
  end
end
