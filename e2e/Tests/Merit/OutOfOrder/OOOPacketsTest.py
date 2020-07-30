from typing import IO, Dict, Any
import json

from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

def OOOPacketTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/OutOfOrder/Packets.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  Liver(rpc, vectors["blockchain"], Transactions.fromJSON(vectors["transactions"])).live()
  file.close()
