#Tests proper handling of Verifications with unsynced Transactions which are beaten by other Transactions.

#Types.
from typing import Dict, IO, Any

#Transaction class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#JSON standard lib.
import json

def VCompetingTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Competing.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Transactions.
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Function to verify the right Transaction was confirmed.
  def verifyConfirmation() -> None:
    if not rpc.call("consensus", "getStatus", [vectors["verified"]])["verified"]:
      raise TestError("Didn't verify the Send which should have been verified.")

    if rpc.call("consensus", "getStatus", [vectors["beaten"]])["verified"]:
      raise TestError("Did verify the Send which should have been beaten.")

  #Create and execute a Liver/Syncer.
  Liver(rpc, vectors["blockchain"], transactions, callbacks={19: verifyConfirmation}).live()
  Syncer(rpc, vectors["blockchain"], transactions).sync()
