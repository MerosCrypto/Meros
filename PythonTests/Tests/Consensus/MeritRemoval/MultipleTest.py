#Tests proper creation and handling of multiple MeritRemovals when Meros receives multiple causes for a MeritRemoval.

#Types.
from typing import Dict, List, IO, Any

#SignedMeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def MultipleTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Multiple.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #MeritRemovals.
  removals: List[SignedMeritRemoval] = [
    SignedMeritRemoval.fromSignedJSON(vectors["removals"][0]),
    SignedMeritRemoval.fromSignedJSON(vectors["removals"][1])
  ]

  #Send and verify the MeritRemoval.
  def sendMeritRemovals() -> None:
    removalBuf: bytes = rpc.meros.signedElement(removals[0])
    if removalBuf != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removals[0].holder, True)

    rpc.meros.signedElement(removals[1])
    if removalBuf != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the first Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removals[0].holder, True)

  #Verify the holder has 0 Merit and is marked as malicious.
  def verifyFirstMeritRemoval() -> None:
    verifyMeritRemoval(rpc, 0, 0, removals[0].holder, True)

  #Create and execute a Liver to handle the Signed MeritRemovals.
  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendMeritRemovals,
      2: verifyFirstMeritRemoval,
      3: lambda: verifyMeritRemoval(rpc, 0, 0, removals[0].holder, False)
    }
  ).live()

  #Create and execute a Syncer to handle a Signed MeritRemoval.
  Syncer(rpc, vectors["blockchain"]).sync()
  verifyMeritRemoval(rpc, 0, 0, removals[0].holder, False)
