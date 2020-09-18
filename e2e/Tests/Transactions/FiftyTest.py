#https://github.com/MerosCrypto/Meros/issues/50

from typing import Dict, Any
import json

from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

def FiftyTest(
  rpc: RPC
) -> None:
  with open("e2e/Vectors/Transactions/Fifty.json", "r") as file:
    vectors: Dict[str, Any] = json.loads(file.read())
    Liver(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).live()
    Syncer(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).sync()
