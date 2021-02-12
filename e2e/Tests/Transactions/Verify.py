from time import sleep

from e2e.Classes.Transactions.Transactions import Transaction, Transactions

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def verifyTransaction(
  rpc: RPC,
  tx: Transaction
) -> None:
  sleep(1)
  if rpc.call("transactions", "getTransaction", {"hash": tx.hash.hex()}) != tx.toJSON():
    raise TestError("Transaction doesn't match.")

def verifyTransactions(
  rpc: RPC,
  transactions: Transactions
) -> None:
  for tx in transactions.txs:
    verifyTransaction(rpc, transactions.txs[tx])
