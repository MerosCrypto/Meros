from typing import List, IO, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def LocksTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/ChainAdvancement.json", "r")
  #Including the genesis Block, this sets a height of 10.
  #There's a grace period from Blocks 1-5. Then 6-10 is a full Checkpoint period.
  #As soon as Block 10 is mined, the Merit should lock.
  chain: List[Any] = json.loads(file.read())[0][:9]
  file.close()

  def verifyLockedOnTime(
    height: int
  ) -> None:
    if (height < 9) != rpc.call("merit", "getMerit", [0])["unlocked"]:
      raise TestError("Meros was locked early/not locked at all.")

  Liver(rpc, chain, everyBlock=verifyLockedOnTime).live()
