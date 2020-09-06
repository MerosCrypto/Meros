#Tests proper handling of a MeritRemoval created from Verifications verifying competing Transactions.

from typing import Dict, List, Any
import json

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError
from e2e.Tests.Consensus.Verify import verifyMeritRemoval

def VerifyCompetingTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/MeritRemoval/VerifyCompeting.json", "r") as file:
    vectors = json.loads(file.read())

  datas: List[Data] = [
    Data.fromJSON(vectors["datas"][0]),
    Data.fromJSON(vectors["datas"][1]),
    Data.fromJSON(vectors["datas"][2])
  ]

  transactions: Transactions = Transactions()
  for data in datas:
    transactions.add(data)

  #Initial Data's Verification.
  verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])

  removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removal"])

  #Create and execute a Liver to cause a Signed MeritRemoval.
  def sendElements() -> None:
    #Send the Datas.
    for data in datas:
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't send us the Data.")

    #Send the initial Data's verification.
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't us the initial Data's Verification.")

    #Send the first Element.
    if rpc.meros.signedElement(removal.se1) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Verification.")

    #Trigger the MeritRemoval.
    rpc.meros.signedElement(removal.se2)
    if rpc.meros.live.recv() != (
      MessageType.SignedMeritRemoval.toByte() +
      removal.signedSerialize()
    ):
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removal.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    transactions,
    callbacks={
      1: sendElements,
      2: lambda: verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
    }
  ).live()

  #Create and execute a Liver to handle a Signed MeritRemoval.
  def sendMeritRemoval() -> None:
    #Send the Datas.
    for data in datas:
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't send us the Data.")

    #Send the initial Data's verification.
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't us the initial Data's Verification.")

    #Send and verify the MeritRemoval.
    if rpc.meros.signedElement(removal) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, removal.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    transactions,
    callbacks={
      1: sendMeritRemoval,
      2: lambda: verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
    }
  ).live()

  #Create and execute a Syncer to handle a Signed MeritRemoval.
  Syncer(rpc, vectors["blockchain"], transactions).sync()
  verifyMeritRemoval(rpc, 1, 1, removal.holder, False)
