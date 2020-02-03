#Tests proper handling of a MeritRemoval created from Verifications verifying competing, and invalid, Transactions.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#MeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#Blockchain verifier.
from PythonTests.Tests.Merit.Verify import verifyBlockchain

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#JSON standard lib.
import json

def InvalidCompetingTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/InvalidCompeting.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #MeritRemoval.
    #pylint: disable=no-member
    removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removal"])

    #Create and execute a Liver to handle the MeritRemoval.
    def sendMeritRemoval() -> None:
        #Send and verify the MeritRemoval.
        removalBytes: bytes = rpc.meros.signedElement(removal)

        sent: int = 0
        while True:
            if sent == 2:
                break

            msg: bytes = rpc.meros.sync.recv()
            if MessageType(msg[0]) == MessageType.TransactionRequest:
                rpc.meros.syncTransaction(transactions.txs[msg[1 : 33]])
                sent += 1
            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

        if removalBytes != rpc.meros.live.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 1, removal.holder, True)

    #Verify the MeritRemoval and the Blockchain.
    def verify() -> None:
        verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
        verifyBlockchain(rpc, Blockchain.fromJSON(vectors["blockchain"]))
        raise SuccessError("MeritRemoval and Blockchain were properly handled.")

    Liver(
        rpc,
        vectors["blockchain"],
        transactions,
        callbacks={
            1: sendMeritRemoval,
            2: verify
        }
    ).live()
