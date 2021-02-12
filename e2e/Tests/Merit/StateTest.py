#Tests incremental Merit addition/death over time.
#These are the most fundamental part of the State and required by both codebases to work perfectly.
#Doesn't test Merit Removals or any MeritStatus other than Unlocked.

from typing import Dict, List, Any
import json

from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Classes.Merit.State import State

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def StateTest(
  rpc: RPC
) -> None:
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Merit/State.json", "r") as file:
    vectors = json.loads(file.read())

  blockchain: Blockchain = Blockchain.fromJSON(vectors)
  state: State = State()

  def checkState(
    block: int
  ) -> None:
    state.add(blockchain, block)

    meritSum: int = 0
    for miner in range(len(state.balances)):
      meritSum += state.balances[miner]
      if rpc.call("merit", "getMerit", {"nick": miner}) != {
        "status": "Unlocked",
        "malicious": False,
        "merit": state.balances[miner]
      }:
        raise TestError("Merit doesn't match.")

    if meritSum != min(block, state.lifetime):
      raise TestError("Merit sum is invalid.")

  Liver(rpc, vectors, everyBlock=checkState).live()
