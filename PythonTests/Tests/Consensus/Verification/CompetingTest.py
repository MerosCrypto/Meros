#Tests proper handling of Verifications with unsynced Transactions which are beaten by other Transactions.

#Types.
from typing import Dict, IO, Any

#Transaction class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus class.
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Syncer import Syncer

#JSON standard lib.
import json

def VCompetingTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Competing.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Consensus.
    consensus: Consensus = Consensus.fromJSON(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
        vectors["consensus"]
    )
    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #Create and execute a Syncer.
    syncer: Syncer = Syncer(
        rpc,
        Blockchain.fromJSON(
            b"MEROS_DEVELOPER_NETWORK",
            60,
            int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
            vectors["blockchain"]
        ),
        consensus,
        transactions
    )
    syncer.sync()
