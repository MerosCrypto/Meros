#Types.
from typing import Dict, List, IO, Any

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

#JSON standard lib.
import json

def ChainAdvancementTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  #Create and execute a Liver/Syncer.
  Liver(rpc, blocks).live()
  Syncer(rpc, blocks).sync()
