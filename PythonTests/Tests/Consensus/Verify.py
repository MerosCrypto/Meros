#TestError Exception.
from PythonTests.Tests.Errors import TestError

#RPC class.
from PythonTests.Meros.RPC import RPC

#Verify the Data Difficulty.
def verifyDataDifficulty(
    rpc: RPC,
    dataDiff: bytes
) -> None:
    if rpc.call("consensus", "getDataDifficulty") != dataDiff.hex():
        raise TestError("Data Difficulty doesn't match.")
