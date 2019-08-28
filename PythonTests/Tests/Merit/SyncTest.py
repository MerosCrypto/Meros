#Types.
from typing import Dict, List, IO, Any

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Syncer import Syncer

#JSON standard lib.
import json

def MSyncTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    #Create and execute a Syncer.
    Syncer(
        rpc,
        Blockchain.fromJSON(
            b"MEROS_DEVELOPER_NETWORK",
            60,
            int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
            blocks
        )
    ).sync()
