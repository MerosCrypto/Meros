from typing import Dict, List, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

def KeyChangeTest(
  rpc: RPC
) -> None:
  with open("e2e/Vectors/Merit/RandomX/KeyChange.json", "r") as file:
    chain: List[Dict[str, Any]] = json.loads(file.read())
    Liver(rpc, chain).live()
    Syncer(rpc, chain).sync()
