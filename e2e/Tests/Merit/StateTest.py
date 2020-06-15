#Tests incremental Merit addition/death over time.
#These are the most fundamental part of the State and required by both codebases to work perfectly.
#Doesn't test Merit Removals or any MeritStatus other than Unlocked.

from typing import Dict, List, IO, Any
import json

from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Classes.Merit.State import State

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def StateTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/State.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  blockchain: Blockchain = Blockchain.fromJSON(blocks)
  state: State = State()

  def checkState(
    block: int
  ) -> None:
    state.add(blockchain, block)

    meritSum: int = 0
    for miner in state.unlocked:
      meritSum += state.unlocked[miner]
      if rpc.call("merit", "getMerit", [miner]) != {
        "unlocked": True,
        "malicious": False,
        "merit": state.unlocked[miner]
      }:
        raise TestError("Merit doesn't match.")

    if meritSum != min(block, state.lifetime):
      raise TestError("Merit sum is invalid.")

  Liver(rpc, blocks, everyBlock=checkState).live()
