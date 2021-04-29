#Tests that a Transaction added to the Transactions DAG, yet not mentioned while it can still be added, is pruned.

from typing import Dict, List, Any
import json

from pytest import raises

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def PruneUnaddableTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/Prune/PruneUnaddable.json", "r") as file:
    vectors = json.loads(file.read())

  datas: List[Data] = [Data.fromJSON(data) for data in vectors["datas"]]

  def sendDatas() -> None:
    for data in datas:
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't send back the Data.")

    #Send the winning descendant Data's verification.
    verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the SignedVerification.")

    #The Liver thinks we sent this packet, so it shouldn't have to.
    #That said, that'd only be true if this was included in the Sketcher.
    #As its parent is unmentioned, it won't be.
    del rpc.meros.sentVerifs[verif.hash]

  def verifyAdded() -> None:
    for data in datas:
      rpc.call("transactions", "getTransaction", {"hash": data.hash.hex()})
      rpc.call("consensus", "getStatus", {"hash": data.hash.hex()})

  def verifyPruned() -> None:
    for data in datas[2:]:
      with raises(TestError):
        rpc.call("transactions", "getTransaction", {"hash": data.hash.hex()})
      with raises(TestError):
        rpc.call("consensus", "getStatus", {"hash": data.hash.hex()})

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendDatas,
      2: verifyAdded,
      7: verifyPruned
    }
  ).live()
