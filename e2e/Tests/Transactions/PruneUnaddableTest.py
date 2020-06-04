#Tests that a Transaction added to the Transactions DAG, yet not mentioned while it can still be added, is pruned.

#Types.
from typing import Dict, IO, Any

#Data class.
from e2e.Classes.Transactions.Data import Data

#SignedVerification class.
from e2e.Classes.Consensus.Verification import SignedVerification

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

#TestError Exception.
from e2e.Tests.Errors import TestError

#JSON standard lib.
import json

def PruneUnaddableTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Transactions/PruneUnaddable.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  pruned: bytes = Data.fromJSON(vectors["datas"][2]).hash
  prunedDescendant: bytes = Data.fromJSON(vectors["datas"][3]).hash

  def sendDatas() -> None:
    for data in vectors["datas"]:
      if rpc.meros.liveTransaction(Data.fromJSON(data)) != rpc.meros.live.recv():
        raise TestError("Meros didn't send back the Data.")

    #Send the beaten Data's descendant's verification.
    if rpc.meros.signedElement(SignedVerification.fromSignedJSON(vectors["verification"])) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the SignedVerification.")

  def verifyAdded() -> None:
    rpc.call("transactions", "getTransaction", [pruned.hex()])
    rpc.call("consensus", "getStatus", [pruned.hex()])

  def verifyPruned() -> None:
    try:
      rpc.call("transactions", "getTransaction", [pruned.hex()])
      rpc.call("transactions", "getTransaction", [prunedDescendant.hex()])
      rpc.call("consensus", "getStatus", [pruned.hex()])
      rpc.call("consensus", "getStatus", [prunedDescendant.hex()])
      raise Exception()
    except TestError:
      pass
    except Exception:
      raise TestError("Meros didn't prune the Transaction.")

  #Create and execute a Liver.
  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendDatas,
      2: verifyAdded,
      8: verifyPruned
    }
  ).live()
