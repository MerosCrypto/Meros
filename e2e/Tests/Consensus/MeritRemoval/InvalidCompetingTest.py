#Tests proper handling of a MeritRemoval created from Verifications verifying competing, and invalid, Transactions.

from typing import Dict, IO, Any
import json

from pytest import raises

from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from e2e.Classes.Transactions.Transactions import Transactions
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError
from e2e.Tests.Consensus.Verify import verifyMeritRemoval
from e2e.Tests.Merit.Verify import verifyBlockchain

def InvalidCompetingTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/InvalidCompeting.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removal"])
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

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

  with raises(SuccessError):
    Liver(
      rpc,
      vectors["blockchain"],
      transactions,
      callbacks={
        1: sendMeritRemoval,
        2: verify
      }
    ).live()
