#Tests proper handling of a MeritRemoval when Meros receives a SignedMeritRemoval of Elements verifying competing transactions.

#EmptyError Exception.
from python_tests.Tests.Errors import EmptyError

#RPC class.
from python_tests.Meros.RPC import RPC

def MRVCLiveTest(
    rpc: RPC
) -> None:
    raise EmptyError()
