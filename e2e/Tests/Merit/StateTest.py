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
  file: IO[Any] = open("e2e/Vectors/Merit/StateBlocks.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  blockchain: Blockchain = Blockchain.fromJSON(blocks)
  state: State = State()

  def checkState(
    block: int
  ) -> None:
    state.add(blockchain, block)

    for miner in state.unlocked:
      if rpc.call("merit", "getMerit", [miner]) != {
        "unlocked": True,
        "malicious": False,
        "merit": state.unlocked[miner]
      }:
        raise TestError("Merit doesn't match.")

  Liver(rpc, blocks, everyBlock=checkState).live()
