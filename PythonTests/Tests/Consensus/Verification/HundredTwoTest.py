#https://github.com/MerosCrypto/Meros/issues/102.

#Types.
from typing import Dict, IO, Any

#Transaction class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#JSON standard lib.
import json

def HundredTwoTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/HundredTwo.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

    #Verifies the Transaction is added, it has the right holders, the holders Merit surpasses the threshold, yet it isn't verified.
    def verify() -> None:
        for tx in transactions.txs:
            status: Dict[str, Any] = rpc.call("consensus", "getStatus", [tx.hex()])
            print(status)
            if set(status["verifiers"]) != set([0, 1]):
                raise TestError("Meros doesn't have the right list of verifiers for this Transaction.")

            if status["merit"] != 80:
                raise TestError("Meros doesn't have the right amount of Merit for this Transaction.")

            if rpc.call("merit", "getMerit", [0])["merit"] + rpc.call("merit", "getMerit", [1])["merit"] < status["threshold"]:
                raise TestError("Merit sum of holders is less than the threshold.")

            if status["verified"]:
                raise TestError("Meros verified the Transaction which won't have enough Merit by the time the Transaction finalizes.")

    #Create and execute a Liver.
    Liver(rpc, vectors["blockchain"], transactions, callbacks={100: verify}).live()
