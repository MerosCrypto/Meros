#Tests the proper handling of Transactions which try to spend an underflow.

#Types.
from typing import Dict, IO, Any

#Merit class.
from PythonTests.Classes.Merit.Merit import Merit

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Transactions classes.
from PythonTests.Classes.Transactions.Transactions import Transactions
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Send import Send

#Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#Ed25519 lib.
import ed25519

#JSON standard lib.
import json

def HundredFortySevenTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Transactions/ClaimedMint.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Merit.
    merit: Merit = Merit.fromJSON(vectors["blockchain"])
    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #Ed25519 keys.
    privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
    pubKey: ed25519.VerifyingKey = privKey.get_verifying_key()

    #Grab the Claim hash,
    claim: bytes = merit.blockchain.blocks[-1].body.packets[0].hash

    #Create a Send which underflows.
    send: Send = Send(
        [(claim, 0)],
        [
            (pubKey.to_bytes(), 18446744073709551231),
            (pubKey.to_bytes(), 385 + Claim.fromTransaction(transactions.txs[claim]).amount)
        ]
    )
    send.sign(privKey)
    send.beat(SpamFilter(3))

    #Custom function to send the last Block and verify it errors at the right place.
    def checkFail() -> None:
        #Send the Send.
        rpc.meros.liveTransaction(send)

        #Handle sync requests.
        while True:
            #Try receiving from the Live socket, where Meros sends keep-alives.
            try:
                if len(rpc.meros.live.recv()) != 0:
                    raise Exception()
            except TestError:
                raise SuccessError("Node disconnected us after we sent an invalid Transaction.")
            except Exception:
                raise TestError("Meros sent a keep-alive.")

    #Create and execute a Liver.
    Liver(rpc, vectors["blockchain"], transactions, callbacks={12: checkFail}).live()
