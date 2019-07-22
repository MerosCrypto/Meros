#Types.
from typing import Dict, Any

#Transaction classes.
from python_tests.Classes.Transactions.Transaction import Transaction
from python_tests.Classes.Transactions.Send import Send
from python_tests.Classes.Transactions.Data import Data
from python_tests.Classes.Transactions.SpamFilter import SpamFilter

#Transactions class.
class Transactions:
    #Constructor.
    def __init__(
        self,
        sendDiff: bytes,
        dataDiff: bytes
    ) -> None:
        self.sendFilter = SpamFilter(sendDiff)
        self.dataFilter = SpamFilter(dataDiff)
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
    ) -> Dict[str, Transaction]:
        result: Dict[str, Transaction] = {}
        for tx in self.txs:
            result[tx.hex().upper()] = self.txs[tx].toJSON()
        return result

    #JSON -> Transactions.
    @staticmethod
    def fromJSON(
        sendDiff: bytes,
        dataDiff: bytes,
        json: Dict[str, Dict[str, Any]]
    ) -> Any:
        result = Transactions(
            sendDiff,
            dataDiff
        )
        for tx in json:
            if json[tx]["descendant"] == "send":
                result.add(Send.fromJSON(json[tx]))
            elif json[tx]["descendant"] == "data":
                result.add(Data.fromJSON(json[tx]))
        return result
