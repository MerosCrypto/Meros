"""
#Tests proper handling of multiple MeritRemovals.
#Tests proper creation and handling of multiple MeritRemovals when Meros receives multiple causes for a MeritRemoval.

#Types.
from typing import Dict, IO, Any

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#SignedMeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def MultipleTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Multiple.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Blockchain
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )

    #MeritRemovals.
    removal1: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal1"])
    removal2: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal2"])

    #Data.
    data: Data = Data.fromJSON(vectors["data"])

    #Create and execute a Liver to cause multiple MeritRemovals.
    def sendElements() -> None:
        #Send the Data.
        if rpc.meros.transaction(data) != rpc.meros.recv():
            raise TestError("Unexpected message sent.")

        #Send the first SignedElement.
        if rpc.meros.signedElement(removal1.se1) != rpc.meros.recv():
            raise TestError("Unexpected message sent.")
        #Send the second.
        rpc.meros.signedElement(removal1.se2)

        #Verify the first MeritRemoval.
        if rpc.meros.recv() != (MessageType.SignedMeritRemoval.toByte() + removal1.signedSerialize()):
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal1, True)

        #Send the third SignedElement.
        rpc.meros.signedElement(removal2.se2)

        #Meros should treat the first created MeritRemoval as the default MeritRemoval.
        if rpc.meros.recv() != (MessageType.SignedMeritRemoval.toByte() + removal1.signedSerialize()):
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal1, True)

    Liver(
        rpc,
        blockchain,
        callbacks={
            1: sendElements,
            2: lambda: verifyMeritRemoval(rpc, 1, 100, removal2, False)
        }
    ).live()

    #Create and execute a Liver to handle multiple MeritRemovals.
    def sendMeritRemovals() -> None:
        #Send and verify the first MeritRemoval.
        msg = rpc.meros.signedElement(removal1)
        if msg != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal1, True)

        #Send the second MeritRemoval.
        rpc.meros.signedElement(removal2)
        #Meros should treat the first created MeritRemoval as the default.
        if msg != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal1, True)

    Liver(
        rpc,
        blockchain,
        callbacks={
            1: sendMeritRemovals,
            2: lambda: verifyMeritRemoval(rpc, 1, 100, removal2, False)
        }
    ).live()

    #Only a single MeritRemoval is archived.
"""
