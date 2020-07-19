from typing import Dict, List, IO, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def NodeThresholdAdjustmentTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
  vectors: List[Dict[str, Any]] = json.loads(file.read())[:9]
  file.close()

  def verifyThreshold(
    b: int
  ) -> None:
    data: str = rpc.call("personal", "data", ["aabb"])
    #Swallow the new Data(s).
    if b == 1:
      rpc.meros.live.recv()
    rpc.meros.live.recv()
    if b < 9:
      if rpc.call("consensus", "getStatus", [data])["threshold"] != (max(b + 6, 5) // 5 * 4) + 1:
        raise TestError("Meros didn't calculate the right node threshold. That said, this isn't defined by the protocol.")
    else:
      if rpc.call("consensus", "getStatus", [data])["threshold"] != 5:
        raise TestError("Meros didn't lower the node threshold.")

  Liver(rpc, vectors, everyBlock=verifyThreshold).live()
