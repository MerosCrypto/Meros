#Tests proper handling of singular SendDifficulties.
#Does test that SendDifficulties from before having votes are applied when the Merit Holder gains votes.
#Doesn't test signed SendDifficulties, despite having a Liver.

from typing import Callable, Dict, List, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Consensus.Verify import verifySendDifficulty, verifyMeritRemoval

#pylint: disable=too-many-statements
def SendDifficultyTest(
  rpc: RPC
) -> None:
  #Verify functions.
  vddStarting: Callable[[], None] = lambda: verifySendDifficulty(rpc, 3)
  vddEarnedVote: Callable[[], None] = lambda: verifySendDifficulty(rpc, 2)
  vddVoted: Callable[[], None] = lambda: verifySendDifficulty(rpc, 1)
  def vmr() -> None:
    verifyMeritRemoval(rpc, 52, 52, 0, False)
    vddStarting()
  def vEarnedBack() -> None:
    vddEarnedVote()

  #Create and execute a Liver/Syncer.
  with open("e2e/Vectors/Consensus/Difficulties/SendDifficulty.json", "r") as file:
    vectors: List[Dict[str, Any]] = json.loads(file.read())
    Liver(
      rpc,
      vectors,
      callbacks={
        26: vddStarting,
        50: vddEarnedVote,
        51: vddVoted,
        52: vmr,
        102: vEarnedBack
      }
    ).live()
    Syncer(rpc, vectors).sync()
