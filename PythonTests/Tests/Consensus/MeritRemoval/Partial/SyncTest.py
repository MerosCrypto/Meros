#Tests proper handling of a MeritRemoval when Meros syncs a partial MeritRemoval.

#Types.
from typing import Dict, IO, Any

#Transaction classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from PythonTests.Classes.Consensus.MeritRemoval import MeritRemoval
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

def MRPSyncTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Partial.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #MeritRemoval.
    removal: MeritRemoval = MeritRemoval.fromJSON(vectors["removal"])
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    consensus.add(removal.e1)
    consensus.add(removal)
    #Transactions.
    transactions: Transactions = Transactions()
    transactions.add(Data.fromJSON(vectors["data"]))

    #Create and execute a Syncer.
    Syncer(
        rpc,
        Blockchain.fromJSON(
            b"MEROS_DEVELOPER_NETWORK",
            60,
            int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
            vectors["blockchain"]
        ),
        consensus,
        transactions
    ).sync()

    #Verify the MeritRemoval.
    verifyMeritRemoval(rpc, 2, 200, removal, False)
