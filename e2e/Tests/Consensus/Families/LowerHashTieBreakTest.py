from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Data import Data

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def LowerHashTieBreakTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/LowerHashTieBreak.json", "r") as file:
    vectors = json.loads(file.read())
  datas: List[Data] = [Data.fromJSON(data) for data in vectors["datas"]]

  def sendDatas() -> None:
    for d in range(len(datas)):
      if rpc.meros.liveTransaction(datas[d]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Data.")

  def verifyLowerHashWon() -> None:
    data: Data = datas[1]
    if int.from_bytes(data.hash, "little") > int.from_bytes(datas[2].hash, "little"):
      data = datas[2]
    if not rpc.call("consensus", "getStatus", {"hash": data.hash.hex()})["verified"]:
      raise TestError("Meros didn't verify the tied Transaction with a lower hash.")

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      40: sendDatas,
      46: verifyLowerHashWon
    }
  ).live()
