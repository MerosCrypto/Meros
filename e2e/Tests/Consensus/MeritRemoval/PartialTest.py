#Tests proper handling of a MeritRemoval where one Element is already archived.

from typing import Dict, Any
import json

from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError
from e2e.Tests.Consensus.Verify import verifyMeritRemoval

def PartialTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/MeritRemoval/Partial.json", "r") as file:
    vectors = json.loads(file.read())

  removal: PartialMeritRemoval = PartialMeritRemoval.fromSignedJSON(vectors["removal"])

  #Create and execute a Liver to cause a Partial MeritRemoval.
  def sendElement() -> None:
    #Send the second Element.
    rpc.meros.signedElement(removal.se2)

    #Verify the MeritRemoval.
    if rpc.meros.live.recv() != (
      MessageType.SignedMeritRemoval.toByte() +
      removal.serialize()
    ):
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 2, 2, removal.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      2: sendElement,
      3: lambda: verifyMeritRemoval(rpc, 2, 2, removal.holder, False)
    }
  ).live()

  #Create and execute a Liver to handle a Partial MeritRemoval.
  def sendMeritRemoval() -> None:
    #Send and verify the MeritRemoval.
    if rpc.meros.meritRemoval(removal) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 2, 2, removal.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      2: sendMeritRemoval,
      3: lambda: verifyMeritRemoval(rpc, 2, 2, removal.holder, False)
    }
  ).live()

  #Create and execute a Syncer to handle a Partial MeritRemoval.
  Syncer(rpc, vectors["blockchain"]).sync()
  verifyMeritRemoval(rpc, 2, 2, removal.holder, False)
