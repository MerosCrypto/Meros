#https://github.com/MerosCrypto/Meros/issues/50

#Types.
from typing import Dict, IO, Any

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#JSON standard lib.
import json

def FiftyTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Transactions/Fifty.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Create and execute a Liver/Syncer.
    Liver(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).live()
    Syncer(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).sync()
