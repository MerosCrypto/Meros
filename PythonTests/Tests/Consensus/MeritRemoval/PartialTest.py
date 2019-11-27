#Tests proper handling of a MeritRemoval where one Element is already archived.

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

#RPC class.
from PythonTests.Meros.RPC import RPC

def PartialTest(
    rpc: RPC
) -> None:
    raise EmptyError()
