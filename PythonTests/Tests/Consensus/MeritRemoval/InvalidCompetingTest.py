#Tests proper handling of a MeritRemoval created from Verifications verifying competing, and invalid, Transactions.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#MeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

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
        verifyMeritRemoval(rpc, 11, 11, removal.holder, True)

    Liver(
        rpc,
        vectors["blockchain"],
        transactions,
        callbacks={
            11: sendMeritRemoval,
            12: lambda: verifyMeritRemoval(rpc, 11, 11, removal.holder, False)
        }
    ).live()

    #Create and execute a Syncer to handle the MeritRemoval.
    Syncer(rpc, vectors["blockchain"], transactions).sync()
    verifyMeritRemoval(rpc, 11, 11, removal.holder, False)
