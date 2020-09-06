from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def TwoHundredThirtyEightTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/Prune/TwoHundredThirtyEight.json", "r") as file:
    vectors = json.loads(file.read())

  datas: List[Data] = [Data.fromJSON(data) for data in vectors["datas"]]
  verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])

  def sendDatas() -> None:
    for d in range(len(datas)):
      if rpc.meros.liveTransaction(datas[d]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Data.")

    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast the Verification.")

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      42: sendDatas
    }
  ).live()
