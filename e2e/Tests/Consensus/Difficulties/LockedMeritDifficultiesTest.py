import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Consensus.Verify import verifySendDifficulty, verifyDataDifficulty

#This sanity check could false positive if Locked Merit is broken.
#The more basic Locked Merit tests must be checked if this is raised.
INVALID_TEST: str = "Locked Merit Difficulties test has invalid vectors/heights, or Locked Merit is fundamentally broken."

#pylint: disable=too-many-statements
def LockedMeritDifficultyTest(
  rpc: RPC
) -> None:
  def verifyVotedAndUnlocked() -> None:
    if rpc.call("merit", "getMerit", [0])["status"] != "Unlocked":
      raise Exception(INVALID_TEST)
    verifySendDifficulty(rpc, 2)
    verifyDataDifficulty(rpc, 2)

  def verifyDiscountedAndLocked() -> None:
    if rpc.call("merit", "getMerit", [0])["status"] != "Locked":
      raise Exception(INVALID_TEST)
    verifySendDifficulty(rpc, 3)
    verifyDataDifficulty(rpc, 5)

  def verifyCountedAndPending() -> None:
    if rpc.call("merit", "getMerit", [0])["status"] != "Pending":
      raise Exception(INVALID_TEST)
    verifySendDifficulty(rpc, 2)
    verifyDataDifficulty(rpc, 2)

  with open("e2e/Vectors/Consensus/Difficulties/LockedMerit.json", "r") as vectors:
    Liver(
      rpc,
      json.loads(vectors.read()),
      callbacks={
        50: verifyVotedAndUnlocked,
        59: verifyDiscountedAndLocked,
        60: verifyCountedAndPending
      }
    ).live()
