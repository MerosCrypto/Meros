from typing import Dict, List, Any
import json

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def DifficultyTest(
  rpc: RPC
) -> None:
  #Declared here so we can access the difficulties from this callback.
  blockchain: Blockchain
  def checkDifficulty(
    block: int
  ) -> None:
    if rpc.call("merit", "getDifficulty") != blockchain.difficulties[block]:
      raise TestError("Difficulty doesn't match.")

  with open("e2e/Vectors/Merit/Difficulty.json", "r") as file:
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    blockchain = Blockchain.fromJSON(blocks)
    Liver(rpc, blocks, everyBlock=checkDifficulty).live()
