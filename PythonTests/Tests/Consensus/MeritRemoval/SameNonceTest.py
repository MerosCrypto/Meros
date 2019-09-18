#Tests proper handling of a MeritRemoval created from Elements sharing a nonce.

#Types.
from typing import Dict, IO, Any

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

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

def MRSameNonceTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Blockchain
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )
    #MeritRemoval.
    removal: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal"])
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    consensus.add(removal)
    #Data.
    data: Data = Data.fromJSON(vectors["data"])

    #Create and execute a Liver to cause a SameNonce MeritRemoval.
    def sendDataAndVerification() -> None:
        print("Sending Data and Verification")
        #Send the Data/SignedVerifications.
        if rpc.meros.transaction(data) != rpc.meros.recv():
            raise TestError("Unexpected message sent.")

        if rpc.meros.signedElement(removal.se1) != rpc.meros.recv():
            raise TestError("Unexpected message sent.")
        rpc.meros.signedElement(removal.se2)

        #Verify the MeritRemoval.
        if rpc.meros.recv() != (MessageType.SignedMeritRemoval.toByte() + removal.signedSerialize()):
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal, True)

    Liver(
        rpc,
        blockchain,
        consensus,
        callbacks={
            1: sendDataAndVerification
        }
    ).live()
    verifyMeritRemoval(rpc, 1, 100, removal, False)
    rpc.reset()

    #Create and execute a Liver to handle a SameNonce MeritRemoval.
    def sendMeritRemoval() -> None:
        #Send and verify the MeritRemoval.
        if rpc.meros.signedElement(removal) != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal, True)

    Liver(
        rpc,
        blockchain,
        consensus,
        callbacks={
            1: sendMeritRemoval
        }
    ).live()
    verifyMeritRemoval(rpc, 1, 100, removal, False)
    rpc.reset()

    #Create and execute a Syncer to handle a SameNonce MeritRemoval.
    Syncer(rpc, blockchain, consensus).sync()
    verifyMeritRemoval(rpc, 1, 100, removal, False)
