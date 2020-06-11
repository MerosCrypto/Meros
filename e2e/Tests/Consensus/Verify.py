from time import sleep

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def verifySendDifficulty(
  rpc: RPC,
  sendDiff: int
) -> None:
  #Sleep to ensure data races aren't a problem.
  #Of course, this doesn't actually ensure it; just makes the odds extemely unlikely.
  sleep(1)
  if rpc.call("consensus", "getSendDifficulty") != sendDiff:
    raise TestError("Send Difficulty doesn't match.")

def verifyDataDifficulty(
  rpc: RPC,
  dataDiff: int
) -> None:
  sleep(1)
  if rpc.call("consensus", "getDataDifficulty") != dataDiff:
    raise TestError("Data Difficulty doesn't match.")

def verifyMeritRemoval(
  rpc: RPC,
  total: int,
  merit: int,
  holder: int,
  pending: bool
) -> None:
  sleep(1)

  if rpc.call("merit", "getTotalMerit") != total if pending else total - merit:
    raise TestError("Total Merit doesn't match.")

  if rpc.call("merit", "getMerit", [holder]) != {
    "unlocked": True,
    "malicious": pending,
    "merit": merit if pending else 0
  }:
    raise TestError("Holder's Merit doesn't match.")
