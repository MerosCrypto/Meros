#Types.
from typing import Dict, Any

#Transactions classes.
from python_tests.Classes.Transactions.Transaction import Transaction
from python_tests.Classes.Transactions.Claim import Claim
from python_tests.Classes.Transactions.Send import Send
from python_tests.Classes.Transactions.Data import Data

#Transactions class.
class Transactions:
    #Constructor.
    def __init__(
        self
    ) -> None:
        self.txs: Dict[bytes, Transaction] = {}

    #Add an Transaction.
    def add(
        self,
        tx: Transaction
    ) -> None:
        self.txs[tx.hash] = tx

    #Transactions -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Dict[str, Any]]:
        result: Dict[str, Dict[str, Any]] = {}
        for tx in self.txs:
            result[tx.hex().upper()] = self.txs[tx].toJSON()
        return result

    #JSON -> Transactions.
    @staticmethod
    def fromJSON(
        json: Dict[str, Dict[str, Any]]
    ) -> Any:
        result = Transactions()
        for tx in json:
            if json[tx]["descendant"] == "Claim":
                result.add(Claim.fromJSON(json[tx]))
            elif json[tx]["descendant"] == "Send":
                result.add(Send.fromJSON(json[tx]))
            elif json[tx]["descendant"] == "Data":
                result.add(Data.fromJSON(json[tx]))
            else:
                raise Exception("JSON has an unsupported Transaction type: " + json[tx]["descendant"])
        return result
