#Tests proper creation and handling of multiple MeritRemovals when Meros receives multiple causes for a MeritRemoval.

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

#RPC class.
from PythonTests.Meros.RPC import RPC

def MultipleTest(
    rpc: RPC
) -> None:
    raise EmptyError()
