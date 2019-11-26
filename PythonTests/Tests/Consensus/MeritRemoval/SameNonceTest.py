#Tests proper handling of a MeritRemoval created from Difficulty/Gas Price Updates sharing nonces.

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

#RPC class.
from PythonTests.Meros.RPC import RPC

def SameNonceTest(
    rpc: RPC
) -> None:
    raise EmptyError()
