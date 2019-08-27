#Tests proper handling of a MeritRemoval when Meros receives a SignedMeritRemoval of Elements verifying competing transactions.

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

#RPC class.
from PythonTests.Meros.RPC import RPC

def MRVCLiveTest(
    rpc: RPC
) -> None:
    raise EmptyError()
