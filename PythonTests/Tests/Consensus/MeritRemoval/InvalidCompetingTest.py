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

    keys: Dict[bytes, int] = {
        bytes.fromhex(vectors["blockchain"][0]["header"]["miner"]): 0
    }

    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #MeritRemoval.
    #pylint: disable=no-member
    removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(keys, vectors["removal"])

    #Create and execute a Liver to handle the MeritRemoval.
    def sendMeritRemoval() -> None:
        #Send and verify the MeritRemoval.
        removalBytes: bytes = rpc.meros.signedElement(removal)

        done: bool = False
        while True:
            try:
                msg: bytes = rpc.meros.recv()
            except TestError:
                raise TestError("Node disconnected us.")

            if MessageType(msg[0]) == MessageType.Syncing:
                rpc.meros.syncingAcknowledged()
            elif MessageType(msg[0]) == MessageType.TransactionRequest:
                rpc.meros.transaction(transactions.txs[msg[1 : 33]])
            elif MessageType(msg[0]) == MessageType.SyncingOver:
                if done:
                    break
                done = True

        if removalBytes != rpc.meros.recv():
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
