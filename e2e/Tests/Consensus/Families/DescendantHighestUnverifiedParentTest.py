#Same as DescendantHighestVerifiedParent, except the parent doesn't beat its competitor.

from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def DescendantHighestUnverifiedParentTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/DescendantHighestUnverifiedParent.json", "r") as file:
    vectors = json.loads(file.read())
  sends: List[Send] = [Send.fromJSON(send) for send in vectors["sends"]]

  def sendSends() -> None:
    for s in range(len(sends)):
      if rpc.meros.liveTransaction(sends[s]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Send.")

  def verifyDescendantLost() -> None:
    for send in sends[1:]:
      if rpc.call("consensus", "getStatus", [send.hash.hex()])["verified"]:
        raise TestError("Meros verified a beaten transaction or one of its children (one of which is impossible).")
    if not rpc.call("consensus", "getStatus", [sends[0].hash.hex()])["verified"]:
      raise TestError("Meros either didn't verify the descendant or its parent.")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      45: sendSends,
      51: verifyDescendantLost
    }
  ).live()
