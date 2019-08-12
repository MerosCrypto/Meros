#TestError Exception.
from python_tests.Tests.TestError import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

def PendingActionsTest(
    rpc: RPC
) -> None:
    raise TestError("Test is empty.")
