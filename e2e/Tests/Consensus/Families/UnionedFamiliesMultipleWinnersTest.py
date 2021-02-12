from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def UnionedFamiliesMultipleWinnersTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/UnionedFamiliesMultipleWinners.json", "r") as file:
    vectors = json.loads(file.read())
  sends: List[Send] = [Send.fromJSON(send) for send in vectors["sends"]]

  def sendSends() -> None:
    for s in range(len(sends)):
      if rpc.meros.liveTransaction(sends[s]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Send.")

  def verifyMultipleWon() -> None:
    for send in [sends[1], *sends[3:]]:
      if rpc.call("consensus", "getStatus", {"hash": send.hash.hex()})["verified"]:
        raise TestError("Meros verified a transaction which was beaten by another transaction.")
    for send in [sends[0], sends[2]]:
      if not rpc.call("consensus", "getStatus", {"hash": send.hash.hex()})["verified"]:
        raise TestError("Meros didn't verify the verified transaction for each original family.")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      44: sendSends,
      50: verifyMultipleWon
    }
  ).live()
