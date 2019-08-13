#Tests proper handling of a MeritRemoval when Meros creates a partial MeritRemoval.

#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

def MRPCauseTest(
    rpc: RPC
) -> None:
    raise TestError("Test is empty.")
