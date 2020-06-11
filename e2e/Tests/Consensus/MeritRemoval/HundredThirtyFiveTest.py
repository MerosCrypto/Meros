#https://github.com/MerosCrypto/Meros/issues/135.

from typing import Dict, List, IO, Any
import json

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError
from e2e.Tests.Consensus.Verify import verifyMeritRemoval

def HundredThirtyFiveTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredThirtyFive.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Datas.
  datas: List[Data] = [
    Data.fromJSON(vectors["datas"][0]),
    Data.fromJSON(vectors["datas"][1]),
    Data.fromJSON(vectors["datas"][2])
  ]

  #Transactions.
  transactions: Transactions = Transactions()
  for data in datas:
    transactions.add(data)

  #First MeritRemoval.
  mr: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(vectors["removal"])

  def sendMeritRemoval() -> None:
    #Send the Datas.
    for data in datas:
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Meros didn't send us the Data.")

    #Send and verify the original MeritRemoval.
    if rpc.meros.signedElement(mr) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 1, mr.holder, True)

  Liver(
    rpc,
    vectors["blockchain"],
    transactions,
    callbacks={
      1: sendMeritRemoval
    }
  ).live()
