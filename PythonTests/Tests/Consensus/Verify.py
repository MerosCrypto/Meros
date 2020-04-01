#RPC class.
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Sleep standard function.
from time import sleep

#Verify the Send Difficulty.
def verifySendDifficulty(
    rpc: RPC,
    sendDiff: int
) -> None:
    #Sleep to ensure data races aren't a problem.
    sleep(1)

    if rpc.call("consensus", "getSendDifficulty") != sendDiff:
        raise TestError("Send Difficulty doesn't match.")

#Verify the Data Difficulty.
def verifyDataDifficulty(
    rpc: RPC,
    dataDiff: int
) -> None:
    sleep(1)

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
    sleep(1)

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
