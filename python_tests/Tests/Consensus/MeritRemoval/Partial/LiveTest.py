#Tests proper handling of a MeritRemoval when Meros receives a partial SignedMeritRemoval.

#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

def MRPLiveTest(
    rpc: RPC
) -> None:
    raise TestError("Test is empty.")
