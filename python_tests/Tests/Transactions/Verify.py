#Transactions classes.
from python_tests.Classes.Transactions.Transaction import Transaction
from python_tests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from python_tests.Tests.Errors import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

#Verify a Transaction.
def verifyTransaction(
    rpc: RPC,
    tx: Transaction
) -> None:
    if rpc.call("transactions", "getTransaction", [tx.hash.hex()]) != tx.toJSON():
        raise TestError("Transaction doesn't match.")

#Verify the Transactions.
def verifyTransactions(
    rpc: RPC,
    transactions: Transactions
) -> None:
    for tx in transactions.txs:
        verifyTransaction(rpc, transactions.txs[tx])
