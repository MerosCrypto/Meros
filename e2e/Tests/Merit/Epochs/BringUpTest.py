#Tests sending B in Block X, then sending child(B), then sending competitor(B).
#All three should be moved into a new Epoch.

from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def BringUpTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/Epochs/BringUp.json", "r") as file:
    vectors = json.loads(file.read())
  datas: List[Data] = [Data.fromJSON(data) for data in vectors["datas"]]

  def verifyFinalized(
    toCheck: List[Data],
    finalized: bool
  ) -> None:
    for data in toCheck:
      if rpc.call("consensus", "getStatus", {"hash": data.hash.hex()})["finalized"] != finalized:
        raise TestError("Meros didn't correctly finalize a Transaction.")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      #Source Data.
      6: lambda: verifyFinalized([datas[0]], False),
      7: lambda: verifyFinalized([datas[0]], True),
      #Family of Datas.
      8: lambda: verifyFinalized(datas[1:], False),
      9: lambda: verifyFinalized(datas[1:], True)
    }
  ).live()
