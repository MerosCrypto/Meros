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

    #Send the beaten Data's descendant's verification.
    if rpc.meros.signedElement(SignedVerification.fromSignedJSON(vectors["verification"])) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the SignedVerification.")

  def verifyAdded() -> None:
    for data in datas:
      rpc.call("transactions", "getTransaction", [data.hash.hex()])
      rpc.call("consensus", "getStatus", [data.hash.hex()])

  def verifyPruned() -> None:
    for data in datas[2:]:
      with raises(TestError):
        rpc.call("transactions", "getTransaction", [data.hash.hex()])
      with raises(TestError):
        rpc.call("consensus", "getStatus", [data.hash.hex()])

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendDatas,
      2: verifyAdded,
      7: verifyPruned
    }
  ).live()
