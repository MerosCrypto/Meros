import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError

def KeepUnlockedTest(
  rpc: RPC
) -> None:
  def verifyUnlocked(
    _: int
  ) -> None:
    if rpc.call("merit", "getMerit", [0])["status"] != "Unlocked":
      raise TestError("Meros didn't keep Merit unlocked.")

  with open("e2e/Vectors/Merit/LockedMerit/KeepUnlocked.json", "r") as file:
    for chain in json.loads(file.read()):
      Liver(rpc, chain, everyBlock=verifyUnlocked).live()
      Syncer(rpc, chain).sync()
