#Tests proper handling of Verifications with unsynced Transactions which are beaten by other Transactions.

#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

def VCompeting(
    rpc: RPC
) -> None:
    raise TestError("Test is empty.")
