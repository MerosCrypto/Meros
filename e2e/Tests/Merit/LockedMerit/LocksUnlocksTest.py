from typing import Dict, List, IO, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

correctVectorsHeight: bool = False
def LocksUnlocksTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/LockedMerit/LocksUnlocks.json", "r")
  chain: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  def verifyCorrectlyLocked(
    height: int
  ) -> None:
    if rpc.call("merit", "getTotalMerit") != height:
      raise TestError("Meros didn't return the correct amount of total Merit.")
    if rpc.call("merit", "getUnlockedMerit") != height if ((height < 9) or (height == 19)) else 0:
      raise TestError("Meros didn't return the correct amount of Unlocked Merit.")

    if height < 9:
      if rpc.call("merit", "getMerit", [0])["status"] != "Unlocked":
        raise TestError("Merit was locked early.")
    elif height == 9:
      if rpc.call("merit", "getMerit", [0])["status"] != "Locked":
        raise TestError("Merit wasn't locked.")
    elif height < 19:
      if rpc.call("merit", "getMerit", [0])["status"] != "Pending":
        raise TestError("Merit was unlocked early.")
    elif height == 19:
      #This may be the first global used in this codebase.
      #This shouldn't be needed, yet it was at least needed for the checkers.
      #pylint: disable=global-statement
      global correctVectorsHeight
      correctVectorsHeight = True
      if rpc.call("merit", "getMerit", [0])["status"] != "Unlocked":
        raise TestError("Merit wasn't unlocked.")

  Liver(rpc, chain, everyBlock=verifyCorrectlyLocked).live()

  #Generally, these tests don't have such sanity checks.
  #That said, they are beneficial, and the initial version of this test failed due to being a Block short.
  #Because it was a Block short, it also false-positived, as it never ran the Unlock check.
  if not correctVectorsHeight:
    raise Exception("LocksUnlocks vectors have an invalid length.")
