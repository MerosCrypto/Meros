#RPC class.
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Verify the Send Difficulty.
def verifySendDifficulty(
    rpc: RPC,
    sendDiff: int
) -> None:
    if rpc.call("consensus", "getSendDifficulty") != sendDiff:
        raise TestError("Send Difficulty doesn't match.")

#Verify the Data Difficulty.
def verifyDataDifficulty(
    rpc: RPC,
    dataDiff: int
) -> None:
    if rpc.call("consensus", "getDataDifficulty") != dataDiff:
        raise TestError("Data Difficulty doesn't match.")

#Verify a MeritRemoval.
def verifyMeritRemoval(
    rpc: RPC,
    total: int,
    merit: int,
    holder: int,
    pending: bool
) -> None:
    #Verify the total Merit.
    if rpc.call("merit", "getTotalMerit") != total if pending else total - merit:
        raise TestError("Total Merit doesn't match.")

    #Verify the holder's Merit.
    if rpc.call("merit", "getMerit", [holder]) != {
        "unlocked": True,
        "malicious": pending,
        "merit": merit if pending else 0
    }:
        raise TestError("Holder's Merit doesn't match.")
