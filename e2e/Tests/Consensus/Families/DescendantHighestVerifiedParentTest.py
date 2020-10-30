#Tests a family where two competing transactions exist, one with a child who has the most Merit.
#The one with a descendant is the better of the two competing.
#In order for these to be grouped under a single family, they need to be externally unioned.

from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def DescendantHighestVerifiedParentTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/DescendantHighestVerifiedParent.json", "r") as file:
    vectors = json.loads(file.read())
  sends: List[Send] = [Send.fromJSON(send) for send in vectors["sends"]]

  def sendSends() -> None:
    for s in range(len(sends)):
      if rpc.meros.liveTransaction(sends[s]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Send.")

  def verifyDescendantWon() -> None:
    for send in sends[::3]:
      if rpc.call("consensus", "getStatus", [send.hash.hex()])["verified"]:
        raise TestError("Meros verified a beaten, or potentially impossible, transaction.")
    for send in sends[1:3]:
      if not rpc.call("consensus", "getStatus", [send.hash.hex()])["verified"]:
        raise TestError("Meros either didn't verify the descendant or its parent.")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      45: sendSends,
      51: verifyDescendantWon
    }
  ).live()
