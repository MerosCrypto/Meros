from typing import Dict, List, IO, Any
import json

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def DifficultyTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  #Constructed here so we can access the difficulties from this callback
  blockchain: Blockchain = Blockchain.fromJSON(blocks)

  def checkDifficulty(
    block: int
  ) -> None:
    if int(rpc.call("merit", "getDifficulty"), 16) != blockchain.difficulties[block]:
      raise TestError("Difficulty doesn't match.")

  Liver(rpc, blocks, everyBlock=checkDifficulty).live()
