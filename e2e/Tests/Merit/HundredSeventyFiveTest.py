from typing import Dict, IO, Any

import json

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def HundredSeventyFiveTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/HundredSeventyFive.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

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
      1: sendDatasAndVerif
    }
  ).live([verif.hash])
