#Types.
from typing import Dict, List, IO, Any

#Blockchain and State classes.
from PythonTests.Classes.Merit.Blockchain import Blockchain
from PythonTests.Classes.Merit.State import State

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#JSON standard lib.
import json

def StateTest(
  rpc: RPC
) -> None:
  #Blocks.
  file: IO[Any] = open("PythonTests/Vectors/Merit/StateBlocks.json", "r")
  blocks: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  #Blockchain.
  blockchain: Blockchain = Blockchain.fromJSON(blocks)
  #State.
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
