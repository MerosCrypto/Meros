#Tests proper handling of singular DataDifficulties.
#Does test that DataDifficulties from before having votes are applied when the Merit Holder gains votes.
#Doesn't test signed DataDifficulties, despite having a Liver.

#Types.
from typing import Dict, Callable, IO, Any

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#Difficulty/MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyDataDifficulty, verifyMeritRemoval

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def DataDifficultyTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Difficulties/DataDifficulty.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Verify functions.
    vddStarting: Callable[[], None] = lambda: verifyDataDifficulty(rpc, 5)
    vddEarnedVote: Callable[[], None] = lambda: verifyDataDifficulty(rpc, 3)
    vddVoted: Callable[[], None] = lambda: verifyDataDifficulty(rpc, 1)
    def vmr() -> None:
        verifyMeritRemoval(rpc, 52, 52, 0, False)
        vddStarting()
    def vEarnedBack() -> None:
        vddStarting()

    #Create and execute a Liver/Syncer.
    Liver(
        rpc,
        vectors["blockchain"],
        callbacks={
            26: vddStarting,
            50: vddEarnedVote,
            51: vddVoted,
            52: vmr,
            103: vEarnedBack
        }
    ).live()
    Syncer(rpc, vectors["blockchain"]).sync()
