#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

#Verify the Transactions.
def verifyTransactions(
    rpc: RPC,
    transactions: Transactions
) -> None:
    for tx in transactions.txs:
        if rpc.call("transactions", "getTransaction", [tx.hex()]) != transactions.txs[tx].toJSON():
            raise TestError("Transaction doesn't match.")
