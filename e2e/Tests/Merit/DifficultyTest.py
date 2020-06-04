#Types.
from typing import Dict, List, IO, Any

#Blockchain class.
from e2e.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from e2e.Tests.Errors import TestError

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

#JSON standard lib.
import json

def DifficultyTest(
  rpc: RPC
) -> None:
  #Blocks.
  file: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  #Blockchain.
  blockchain: Blockchain = Blockchain.fromJSON(blocks)

  def checkDifficulty(
    block: int
  ) -> None:
    if int(rpc.call("merit", "getDifficulty"), 16) != blockchain.difficulties[block]:
      raise TestError("Difficulty doesn't match.")

  Liver(rpc, blocks, everyBlock=checkDifficulty).live()
