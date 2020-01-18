#Tests proper handling of a MeritRemoval where one Element is already archived.

#Types.
from typing import Dict, List, IO, Any

#PartialMeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import PartialMeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def PartialTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Partial.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    keys: Dict[bytes, int] = {
        bytes.fromhex(vectors["blockchain"][0]["header"]["miner"]): 0
    }
    nicks: List[bytes] = [bytes.fromhex(vectors["blockchain"][0]["header"]["miner"])]

    #MeritRemoval.
    #pylint: disable=no-member
    removal: PartialMeritRemoval = PartialMeritRemoval.fromSignedJSON(nicks, keys, vectors["removal"])

    #Create and execute a Liver to cause a Partial MeritRemoval.
    def sendElement() -> None:
        #Send the second Element.
        rpc.meros.signedElement(removal.se2)

        #Verify the MeritRemoval.
        if rpc.meros.recv() != (
            MessageType.SignedMeritRemoval.toByte() +
            removal.signedSerialize(nicks)
        ):
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 2, 2, removal.holder, True)

    Liver(
        rpc,
        vectors["blockchain"],
        callbacks={
            2: sendElement,
            3: lambda: verifyMeritRemoval(rpc, 2, 2, removal.holder, False)
        }
    ).live()

    #Create and execute a Liver to handle a Partial MeritRemoval.
    def sendMeritRemoval() -> None:
        #Send and verify the MeritRemoval.
        if rpc.meros.signedElement(removal) != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 2, 2, removal.holder, True)

    Liver(
        rpc,
        vectors["blockchain"],
        callbacks={
            2: sendMeritRemoval,
            3: lambda: verifyMeritRemoval(rpc, 2, 2, removal.holder, False)
        }
    ).live()

    #Create and execute a Syncer to handle a Partial MeritRemoval.
    Syncer(rpc, vectors["blockchain"]).sync()
    verifyMeritRemoval(rpc, 2, 2, removal.holder, False)
