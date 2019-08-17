#Tests proper handling of Verifications with Transactions which don't exist.

#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

def VUnknown(
    rpc: RPC
) -> None:
    raise TestError("Test is empty.")
