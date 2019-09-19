#Tests proper handling of a MeritRemoval created from Elements verifying competing Transactions.

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

#RPC class.
from PythonTests.Meros.RPC import RPC

def VerifyCompetingTest(
    rpc: RPC
) -> None:
    raise EmptyError()
