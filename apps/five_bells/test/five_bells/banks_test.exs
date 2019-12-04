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

  describe "accounts" do
    alias FiveBells.Banks.Account

    @valid_attrs %{account_no: "some account_no", cycle: 42, delta: 42, deposit: 42, simulation_id: 42}
    @update_attrs %{account_no: "some updated account_no", cycle: 43, delta: 43, deposit: 43, simulation_id: 43}
    @invalid_attrs %{account_no: nil, cycle: nil, delta: nil, deposit: nil, simulation_id: nil}

    def account_fixture(attrs \\ %{}) do
      {:ok, account} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Banks.create_account()

      account
    end

    test "list_accounts/0 returns all accounts" do
      account = account_fixture()
      assert Banks.list_accounts() == [account]
    end

    test "get_account!/1 returns the account with given id" do
      account = account_fixture()
      assert Banks.get_account!(account.id) == account
    end

    test "create_account/1 with valid data creates a account" do
      assert {:ok, %Account{} = account} = Banks.create_account(@valid_attrs)
      assert account.account_no == "some account_no"
      assert account.cycle == 42
      assert account.delta == 42
      assert account.deposit == 42
      assert account.simulation_id == 42
    end

    test "create_account/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Banks.create_account(@invalid_attrs)
    end

    test "update_account/2 with valid data updates the account" do
      account = account_fixture()
      assert {:ok, %Account{} = account} = Banks.update_account(account, @update_attrs)
      assert account.account_no == "some updated account_no"
      assert account.cycle == 43
      assert account.delta == 43
      assert account.deposit == 43
      assert account.simulation_id == 43
    end

    test "update_account/2 with invalid data returns error changeset" do
      account = account_fixture()
      assert {:error, %Ecto.Changeset{}} = Banks.update_account(account, @invalid_attrs)
      assert account == Banks.get_account!(account.id)
    end

    test "delete_account/1 deletes the account" do
      account = account_fixture()
      assert {:ok, %Account{}} = Banks.delete_account(account)
      assert_raise Ecto.NoResultsError, fn -> Banks.get_account!(account.id) end
    end

    test "change_account/1 returns a account changeset" do
      account = account_fixture()
      assert %Ecto.Changeset{} = Banks.change_account(account)
    end
  end
end
