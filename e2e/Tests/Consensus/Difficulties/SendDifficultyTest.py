#Tests proper handling of singular SendDifficulties.
#Does test that SendDifficulties from before having votes are applied when the Merit Holder gains votes.
#Doesn't test signed SendDifficulties, despite having a Liver.

#Types.
from typing import Dict, Callable, IO, Any

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

#Difficulty/MeritRemoval verifier.
from e2e.Tests.Consensus.Verify import verifySendDifficulty, verifyMeritRemoval

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def SendDifficultyTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/Difficulties/SendDifficulty.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Verify functions.
  vddStarting: Callable[[], None] = lambda: verifySendDifficulty(rpc, 3)
  vddEarnedVote: Callable[[], None] = lambda: verifySendDifficulty(rpc, 5)
  vddVoted: Callable[[], None] = lambda: verifySendDifficulty(rpc, 1)
  def vmr() -> None:
    verifyMeritRemoval(rpc, 52, 52, 0, False)
    vddStarting()
  def vEarnedBack() -> None:
    vddEarnedVote()

  #Create and execute a Liver/Syncer.
  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      26: vddStarting,
      50: vddEarnedVote,
      51: vddVoted,
      52: vmr,
      102: vEarnedBack
    }
  ).live()
  Syncer(rpc, vectors["blockchain"]).sync()
