#Tests proper handling of singular DataDifficulties.
#Does test that DataDifficulties from before having votes are applied when the Merit Holder gains votes.
#Doesn't test signed DataDifficulties, despite having a Liver.

#Types.
from typing import Dict, Callable, IO, Any

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#Difficulty verifier.
from PythonTests.Tests.Consensus.Verify import verifyDataDifficulty

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def DataDifficultyTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Difficulties/DataDifficulty.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )

    #Verify functions.
    vddStarting: Callable[[], None] = lambda: verifyDataDifficulty(rpc, bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"))
    vddEarnedVote: Callable[[], None] = lambda: verifyDataDifficulty(rpc, bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"))
    vddVoted: Callable[[], None] = lambda: verifyDataDifficulty(rpc, bytes.fromhex("888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888"))

    #Create and execute a Liver/Syncer.
    Liver(rpc, blockchain, callbacks={26: vddStarting, 50: vddEarnedVote, 51: vddVoted}).live()
    Syncer(rpc, blockchain).sync()
