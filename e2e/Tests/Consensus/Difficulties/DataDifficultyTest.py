#Tests proper handling of singular DataDifficulties.
#Does test that DataDifficulties from before having votes are applied when the Merit Holder gains votes.
#Doesn't test signed DataDifficulties, despite having a Liver.

from typing import Callable, Dict, List, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Consensus.Verify import verifyDataDifficulty, verifyMeritRemoval

#pylint: disable=too-many-statements
def DataDifficultyTest(
  rpc: RPC
) -> None:
  #Verify functions.
  vddStarting: Callable[[], None] = lambda: verifyDataDifficulty(rpc, 5)
  vddEarnedVote: Callable[[], None] = lambda: verifyDataDifficulty(rpc, 2)
  vddVoted: Callable[[], None] = lambda: verifyDataDifficulty(rpc, 1)
  def vmr() -> None:
    verifyMeritRemoval(rpc, 52, 52, 0, False)
    vddStarting()
  def vEarnedBack() -> None:
    vddStarting()

  with open("e2e/Vectors/Consensus/Difficulties/DataDifficulty.json", "r") as file:
    vectors: List[Dict[str, Any]] = json.loads(file.read())
    Liver(
      rpc,
      vectors,
      callbacks={
        26: vddStarting,
        50: vddEarnedVote,
        51: vddVoted,
        52: vmr,
        103: vEarnedBack
      }
    ).live()
    Syncer(rpc, vectors).sync()
