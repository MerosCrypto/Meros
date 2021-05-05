#Tests the proper handling of Transactions which try to spend an underflow.

from typing import Dict, Any
import json

from pytest import raises

import e2e.Libs.Ristretto.ed25519 as ed25519

from e2e.Classes.Merit.Merit import Merit
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Transactions.Transactions import Transactions
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Send import Send

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def HundredFortySevenTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/ClaimedMint.json", "r") as file:
    vectors = json.loads(file.read())

  merit: Merit = Merit.fromJSON(vectors["blockchain"])
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  pubKey: bytes = privKey.get_verifying_key()

  #Grab the Claim hash,
  claim: bytes = merit.blockchain.blocks[-1].body.packets[0].hash

  #Create a Send which underflows.
  send: Send = Send(
    [(claim, 0)],
    [
      (pubKey, 18446744073709551231),
      (pubKey, 385 + Claim.fromTransaction(transactions.txs[claim]).amount)
    ]
  )
  send.sign(privKey)
  send.beat(SpamFilter(3))

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
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, callbacks={8: checkFail}).live()
