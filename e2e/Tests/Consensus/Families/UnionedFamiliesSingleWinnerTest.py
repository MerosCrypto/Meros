from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def UnionedFamiliesSingleWinnerTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/UnionedFamiliesSingleWinner.json", "r") as file:
    vectors = json.loads(file.read())
  sends: List[Send] = [Send.fromJSON(send) for send in vectors["sends"]]

  def sendSends() -> None:
    for s in range(len(sends)):
      if rpc.meros.liveTransaction(sends[s]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Send.")

  def verifyUnionizingWon() -> None:
    for send in sends[:-1]:
      if rpc.call("consensus", "getStatus", {"hash": send.hash.hex()})["verified"]:
        raise TestError("Meros verified a transaction which was beaten by a unionizing transaction.")
    if not rpc.call("consensus", "getStatus", {"hash": sends[-1].hash.hex()})["verified"]:
      raise TestError("Meros didn't verify the verified unionizing transaction.")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      45: sendSends,
      51: verifyUnionizingWon
    }
  ).live()
