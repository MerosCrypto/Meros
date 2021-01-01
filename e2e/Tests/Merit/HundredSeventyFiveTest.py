from typing import Dict, Any
import json

from e2e.Classes.Transactions.Transactions import Transactions
from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def HundredSeventyFiveTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/HundredSeventyFive.json", "r") as file:
    vectors = json.loads(file.read())

  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])
  verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])

  def sendDatasAndVerif() -> None:
    for tx in transactions.txs:
      if rpc.meros.liveTransaction(transactions.txs[tx]) != rpc.meros.live.recv():
        raise TestError("Meros didn't send us back the Data.")

    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us back the Verification.")

  Liver(
    rpc,
    vectors["blockchain"],
    transactions,
    callbacks={
      7: sendDatasAndVerif
    }
  ).live()
