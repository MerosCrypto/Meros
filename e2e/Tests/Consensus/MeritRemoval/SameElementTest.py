#Tests a MeritRemoval created from the same Elements/same Transaction hashes are rejected.

from typing import Dict, Any
import json

from pytest import raises

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def SameElementTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/MeritRemoval/SameElement.json", "r") as file:
    vectors = json.loads(file.read())

  def testBlockchain(
    b: int
  ) -> None:
    data: Data = Data.fromJSON(vectors["data"])
    removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removals"][b])

    #Create and execute a Liver to send the MeritRemoval.
    def sendMeritRemoval() -> None:
      #Send the Data.
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't send back the Data.")

      rpc.meros.meritRemoval(removal)
      try:
        if len(rpc.meros.live.recv()) != 0:
          raise Exception()
      except TestError:
        raise SuccessError("Meros rejected our MeritRemoval created from the same Element.")
      except Exception:
        raise TestError("Meros accepted our MeritRemoval created from the same Element.")

    Liver(
      rpc,
      vectors["blockchain"],
      callbacks={
        1: sendMeritRemoval
      }
    ).live()

  with raises(SuccessError):
    for i in range(2):
      testBlockchain(i)
