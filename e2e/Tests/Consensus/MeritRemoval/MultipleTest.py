#Tests proper creation and handling of multiple MeritRemovals when Meros receives multiple causes for a MeritRemoval.

from typing import Dict, List, Any
import json

from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError
from e2e.Tests.Consensus.Verify import verifyMeritRemoval

def MultipleTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/MeritRemoval/Multiple.json", "r") as file:
    vectors = json.loads(file.read())

  removals: List[SignedMeritRemoval] = [
    SignedMeritRemoval.fromSignedJSON(vectors["removals"][0]),
    SignedMeritRemoval.fromSignedJSON(vectors["removals"][1])
  ]

  #Send and verify the MeritRemovals.
  def sendMeritRemovals() -> None:
    if rpc.meros.meritRemoval(removals[0]) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removals[0].holder, True)

    if rpc.meros.meritRemoval(removals[1]) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the new Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removals[0].holder, True)

  #Verify the holder has 0 Merit and isn't marked as malicious.
  #Since they had one MeritRemoval archived, they're dead.
  #They should have 0 merit, with the other MR being unaddable and therefore dropped.
  def verifyFirstMeritRemoval() -> None:
    verifyMeritRemoval(rpc, 0, 0, removals[0].holder, False)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendMeritRemovals,
      2: verifyFirstMeritRemoval
    }
  ).live()

  #Create and execute a Syncer to handle a Signed MeritRemoval.
  Syncer(rpc, vectors["blockchain"]).sync()
  verifyMeritRemoval(rpc, 0, 0, removals[0].holder, False)
