#Tests a MeritRemoval created from the same Elements/same Transaction hashes are rejected.

#Types.
from typing import Dict, IO, Any

#Data class.
from e2e.Classes.Transactions.Data import Data

#SignedMeritRemoval class.
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#TestError and SuccessError Exceptions.
from e2e.Tests.Errors import TestError, SuccessError

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

#JSON standard lib.
import json

def SameElementTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/SameElement.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  def testBlockchain(
    b: int
  ) -> None:
    #Data.
    data: Data = Data.fromJSON(vectors["data"])

    #pylint: disable=no-member
    #MeritRemoval.
    removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removals"][b])

    #Create and execute a Liver to send the MeritRemoval.
    def sendMeritRemoval() -> None:
      #Send the Data.
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't send back the Data.")

      rpc.meros.signedElement(removal)
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

  for i in range(2):
    testBlockchain(i)
