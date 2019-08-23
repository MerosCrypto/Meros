#Tests proper creation and handling of a MeritRemoval when Meros receives SignedElements verifying competing transactions.

#EmptyError Exception.
from python_tests.Tests.Errors import EmptyError

#RPC class.
from python_tests.Meros.RPC import RPC

def MRVCCauseTest(
    rpc: RPC
) -> None:
    raise EmptyError()
