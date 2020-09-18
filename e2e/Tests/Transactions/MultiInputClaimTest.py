from typing import Dict, Any
import json

from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

def MultiInputClaimTest(
  rpc: RPC
) -> None:
  with open("e2e/Vectors/Transactions/MultiInputClaim.json", "r") as file:
    vectors: Dict[str, Any] = json.loads(file.read())
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])
    Liver(rpc, vectors["blockchain"], transactions).live()
    Syncer(rpc, vectors["blockchain"], transactions).sync()
