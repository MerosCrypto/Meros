from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def UnmentionedBeatMentionedTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Families/UnmentionedBeatMentioned.json", "r") as file:
    vectors = json.loads(file.read())
  datas: List[Data] = [Data.fromJSON(data) for data in vectors["datas"]]
  verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])

  def sendDatas() -> None:
    for d in range(len(datas)):
      if rpc.meros.liveTransaction(datas[d]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Data.")

    #Might as well send this now.
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast the Verification.")

  def verifyMentionedWon() -> None:
    if not rpc.call("consensus", "getStatus", {"hash": datas[2].hash.hex()})["verified"]:
      raise TestError("Meros didn't verify the only Transaction on chain which has finalized.")

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      41: sendDatas,
      47: verifyMentionedWon
    }
  ).live()
