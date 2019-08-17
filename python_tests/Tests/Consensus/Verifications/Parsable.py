#Tests proper handling of Verifications with unsynced Transactions which are parsable yet have invalid signatures.

#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

def VParsable(
    rpc: RPC
) -> None:
    raise TestError("Test is empty.")
