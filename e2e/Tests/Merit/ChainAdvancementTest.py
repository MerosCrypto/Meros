from typing import Dict, List, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

def ChainAdvancementTest(
  rpc: RPC
) -> None:
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    vectors: List[Dict[str, Any]] = json.loads(file.read())
    Liver(rpc, vectors).live()
    Syncer(rpc, vectors).sync()
