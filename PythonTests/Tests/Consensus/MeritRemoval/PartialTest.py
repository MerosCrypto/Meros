#Tests proper handling of a MeritRemoval where one Element is already archived.

#Types.
from typing import Dict, IO, Any

#Transaction classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from PythonTests.Classes.Consensus.MeritRemoval import PartiallySignedMeritRemoval
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

def PartialTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Partial.json", "r")
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
    removal: PartiallySignedMeritRemoval = PartiallySignedMeritRemoval.fromJSON(vectors["removal"])
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    consensus.add(removal.e1)
    consensus.add(removal)

    #Transactions.
    transactions: Transactions = Transactions()
    transactions.add(Data.fromJSON(vectors["data"]))

    #Create and execute a Liver to cause a Partial MeritRemoval.
    def sendElement() -> None:
        #Send the second Element.
        rpc.meros.signedElement(removal.se2)

        #Verify the MeritRemoval.
        if rpc.meros.recv() != (MessageType.SignedMeritRemoval.toByte() + removal.signedSerialize()):
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 2, 200, removal, True)

    Liver(
        rpc,
        blockchain,
        consensus,
        transactions,
        callbacks={
            2: sendElement,
            3: lambda: verifyMeritRemoval(rpc, 2, 200, removal, False)
        }
    ).live()

    #Create and execute a Liver to handle a Partial MeritRemoval.
    def sendMeritRemoval() -> None:
        #Send and verify the MeritRemoval.
        if rpc.meros.signedElement(removal) != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 2, 200, removal, True)

    Liver(
        rpc,
        blockchain,
        consensus,
        transactions,
        callbacks={
            2: sendMeritRemoval,
            3: lambda: verifyMeritRemoval(rpc, 2, 200, removal, False)
        }
    ).live()

    #Create and execute a Syncer to handle a Partial MeritRemoval.
    Syncer(rpc, blockchain, consensus, transactions).sync()
    verifyMeritRemoval(rpc, 2, 200, removal, False)
