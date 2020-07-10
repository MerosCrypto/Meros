from typing import Dict, List, IO, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError

def KeepUnlockedTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/LockedMerit/KeepUnlocked.json", "r")
  chains: List[List[Dict[str, Any]]] = json.loads(file.read())
  file.close()

  def verifyUnlocked(
    _: int
  ) -> None:
    if rpc.call("merit", "getMerit", [0])["status"] != "Unlocked":
      raise TestError("Meros didn't keep Merit unlocked.")

  for chain in chains:
    Liver(rpc, chain, everyBlock=verifyUnlocked).live()
    Syncer(rpc, chain).sync()
