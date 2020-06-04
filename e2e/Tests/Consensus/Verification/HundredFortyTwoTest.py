#https://github.com/MerosCrypto/Meros/issues/142.
#Tests proper handling of Verifications with never actually get archived.

#Types.
from typing import Dict, IO, Any

#SignedVerification class.
from e2e.Classes.Consensus.Verification import SignedVerification

#Transactions class.
from e2e.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from e2e.Tests.Errors import TestError

#Meros classes.
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

#JSON standard lib.
import json

#pylint: disable=too-many-statements
def HundredFortyTwoTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/Verification/HundredFortyTwo.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Transactions.
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Function to verify the Transaction includes unarchived Merit before finalization.
  def verifyUnarchivedMerit() -> None:
    #Send the verification which won't be archived.
    if rpc.meros.signedElement(SignedVerification.fromSignedJSON(vectors["verification"])) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the SignedVerification.")

    status: Dict[str, Any] = rpc.call("consensus", "getStatus", [vectors["transaction"]])
    if sorted(status["verifiers"]) != [0, 1]:
      raise TestError("Status didn't include verifiers which have yet to be archived.")
    if status["merit"] != 7:
      raise TestError("Status didn't include Merit which has yet to be archived.")

  #Function to verify the Transaction doesn't include unarchived Merit after finalization.
  def verifyArchivedMerit() -> None:
    status: Dict[str, Any] = rpc.call("consensus", "getStatus", [vectors["transaction"]])
    if status["verifiers"] != [0]:
      raise TestError("Status included verifiers which were never archived.")
    if status["merit"] != 1:
      raise TestError("Status included Merit which was never archived.")

  #Create and execute a Liver.
  Liver(rpc, vectors["blockchain"], transactions, callbacks={7: verifyUnarchivedMerit, 8: verifyArchivedMerit}).live()
