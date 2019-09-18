#https://github.com/MerosCrypto/Meros/issues/50

#Types.
from typing import Dict, IO, Any

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Syncer import Syncer
from PythonTests.Meros.Liver import Liver

#JSON standard lib.
import json

def FiftyTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Transactions/Fifty.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )
    consensus: Consensus = Consensus.fromJSON(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
        vectors["consensus"]
    )
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #Create and execute a Syncer/Liver.
    Syncer(rpc, blockchain, consensus, transactions).sync()
    rpc.reset()
    Liver(rpc, blockchain, consensus, transactions).live()
