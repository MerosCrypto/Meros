#Tests proper handling of Verifications with unsynced Transactions which are beaten by other Transactions.

from typing import Dict, Any
import json

from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError

def VCompetingTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Verification/Competing.json", "r") as file:
    vectors = json.loads(file.read())

  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Function to verify the right Transaction was confirmed.
  def verifyConfirmation() -> None:
    if not rpc.call("consensus", "getStatus", {"hash": vectors["verified"]})["verified"]:
      raise TestError("Didn't verify the Send which should have been verified.")

    if rpc.call("consensus", "getStatus", {"hash": vectors["beaten"]})["verified"]:
      raise TestError("Did verify the Send which should have been beaten.")

  Liver(rpc, vectors["blockchain"], transactions, callbacks={19: verifyConfirmation}).live()
  Syncer(rpc, vectors["blockchain"], transactions).sync()
