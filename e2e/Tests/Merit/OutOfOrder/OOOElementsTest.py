from typing import Dict, List, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Consensus.Verify import verifyDataDifficulty

def OOOElementsTest(
  rpc: RPC
) -> None:
  with open("e2e/Vectors/Merit/OutOfOrder/Elements.json", "r") as file:
    vectors: List[Dict[str, Any]] = json.loads(file.read())

    Liver(
      rpc,
      vectors,
      callbacks={
        50: lambda: verifyDataDifficulty(rpc, 1),
        51: lambda: verifyDataDifficulty(rpc, 4)
      }
    ).live()
    Syncer(rpc, vectors).sync()
