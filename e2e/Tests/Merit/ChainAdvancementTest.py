from typing import List, IO, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

def ChainAdvancementTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/ChainAdvancement.json", "r")
  chains: List[Any] = json.loads(file.read())
  file.close()

  for chain in chains:
    Liver(rpc, chain).live()
    Syncer(rpc, chain).sync()
