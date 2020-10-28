#A -> B
# \   |
#  -> D
#There's only a single valid way to resolve this. B.
#This tests an 'impossible' case where D has the most Merit.

from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def ImpossibleFamilyTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/ImpossibleFamily.json", "r") as file:
    vectors = json.loads(file.read())
  sends: List[Send] = [Send.fromJSON(send) for send in vectors["sends"]]

  def sendSends() -> None:
    for s in range(len(sends)):
      if rpc.meros.liveTransaction(sends[s]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Send.")

  def verifyPossibleWon() -> None:
    if rpc.call("consensus", "getStatus", [sends[1].hash.hex()])["verified"]:
      raise TestError("Meros verified an impossible Transaction.")
    if not rpc.call("consensus", "getStatus", [sends[0].hash.hex()])["verified"]:
      raise TestError("Meros didn't verify the only possible Transaction.")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      42: sendSends,
      48: verifyPossibleWon
    }
  ).live()
