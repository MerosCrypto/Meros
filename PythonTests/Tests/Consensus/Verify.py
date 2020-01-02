#TestError Exception.
from PythonTests.Tests.Errors import TestError

#RPC class.
from PythonTests.Meros.RPC import RPC

#Verify the Send Difficulty.
def verifySendDifficulty(
    rpc: RPC,
    sendDiff: bytes
) -> None:
    if rpc.call("consensus", "getSendDifficulty") != sendDiff.hex().upper():
        raise TestError("Send Difficulty doesn't match.")

#Verify the Data Difficulty.
def verifyDataDifficulty(
    rpc: RPC,
    dataDiff: bytes
) -> None:
    if rpc.call("consensus", "getDataDifficulty") != dataDiff.hex().upper():
        raise TestError("Data Difficulty doesn't match.")
