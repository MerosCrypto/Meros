#Tests proper handling of a MeritRemoval when Meros syncs a MeritRemoval of Elements sharing a nonce.

#Types.
from typing import Dict, IO, Any

#Consensus classes.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Syncer import Syncer

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def MRSNSyncTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #MeritRemoval.
    removal: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal"])
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    consensus.add(removal)

    #Create and execute a Syncer.
    Syncer(
        rpc,
        Blockchain.fromJSON(
            b"MEROS_DEVELOPER_NETWORK",
            60,
            int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
            vectors["blockchain"]
        ),
        consensus
    ).sync()

    #Verify the MeritRemoval.
    verifyMeritRemoval(rpc, 1, 100, removal, False)
