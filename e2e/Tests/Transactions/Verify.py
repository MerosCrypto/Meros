from time import sleep

from e2e.Classes.Transactions.Transaction import Transaction
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def verifyTransaction(
  rpc: RPC,
  tx: Transaction
) -> None:
  if rpc.call("transactions", "getTransaction", [tx.hash.hex()]) != tx.toJSON():
    raise TestError("Transaction doesn't match.")

def verifyTransactions(
  rpc: RPC,
  transactions: Transactions
) -> None:
  sleep(2)
  for tx in transactions.txs:
    verifyTransaction(rpc, transactions.txs[tx])
