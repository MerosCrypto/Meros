#Tests proper handling of a MeritRemoval created from Difficulty/Gas Price Updates sharing nonces.

#Types.
from typing import Dict, IO, Any

#SignedMeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def SameNonceTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #MeritRemoval.
  #pylint: disable=no-member
  removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removal"])

  #Create and execute a Liver to cause a Signed MeritRemoval.
  def sendElements() -> None:
    #Send the Elements.
    rpc.meros.signedElement(removal.se1)
    rpc.meros.signedElement(removal.se2)

    #Verify the first Element.
    if rpc.meros.live.recv() != (
      MessageType.SignedDataDifficulty.toByte() +
      removal.se1.signedSerialize()
    ):
      raise TestError("Meros didn't send us the first Data Difficulty.")

    #Verify the MeritRemoval.
    if rpc.meros.live.recv() != (
      MessageType.SignedMeritRemoval.toByte() +
      removal.signedSerialize()
    ):
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removal.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendElements,
      2: lambda: verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
    }
  ).live()

  #Create and execute a Liver to handle a Signed MeritRemoval.
  def sendMeritRemoval() -> None:
    #Send and verify the MeritRemoval.
    if rpc.meros.signedElement(removal) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removal.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendMeritRemoval,
      2: lambda: verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
    }
  ).live()

  #Create and execute a Syncer to handle a Signed MeritRemoval.
  Syncer(rpc, vectors["blockchain"]).sync()
  verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
