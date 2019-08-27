#Tests proper creation and handling of a MeritRemoval when Meros receives SignedElements verifying competing transactions.

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

#RPC class.
from PythonTests.Meros.RPC import RPC

def MRVCCauseTest(
    rpc: RPC
) -> None:
    raise EmptyError()
