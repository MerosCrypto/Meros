#https://github.com/MerosCrypto/Meros/issues/50

#Types.
from typing import Dict, IO, Any

#Transactions class.
from e2e.Classes.Transactions.Transactions import Transactions

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

#JSON standard lib.
import json

def FiftyTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Transactions/Fifty.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Create and execute a Liver/Syncer.
  Liver(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).live()
  Syncer(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).sync()
