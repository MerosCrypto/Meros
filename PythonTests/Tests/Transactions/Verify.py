#Transactions classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#RPC class.
from PythonTests.Meros.RPC import RPC

#Verify a Transaction.
def verifyTransaction(
    rpc: RPC,
    tx: Transaction
) -> None:
    if rpc.call("transactions", "getTransaction", [tx.hash.hex()]) != tx.toJSON():
        raise TestError("Transaction doesn't match.")

    if rpc.call("consensus", "getStatus", [tx.hash.hex()])["verified"] != tx.verified:
        raise TestError("Transaction's status doesn't match.")

#Verify the Transactions.
def verifyTransactions(
    rpc: RPC,
    transactions: Transactions
) -> None:
    for tx in transactions.txs:
        verifyTransaction(rpc, transactions.txs[tx])
