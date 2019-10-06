#Types.
from typing import Dict, List, Any

#BlockBody class.
class BlockBody:
    #Constructor.
    def __init__(
        self,
        transactions: List[bytes] = [],
        elements: List[bytes] = [],
        aggregate: bytes = bytes(96)
    ) -> None:
        #Since Tuples are immutable, shallow copies are fine.
        self.transactions: List[bytes] = list(transactions)
        self.elements: List[bytes] = list(elements)
        self.aggregate: bytes = bytes(aggregate)

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = len(self.transactions).to_bytes(4, "big")
        for tx in self.transactions:
            result += tx

        result += len(self.elements).to_bytes(4, "big")

        result += self.aggregate
        return result

    #BlockBody -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "transactions": [],
            "elements": []
        }

        for tx in self.transactions:
            result["transactions"].append(tx.hex().upper())

        return result

    #JSON -> Blockbody.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        transactions: List[bytes] = []
        elements: List[bytes] = []

        for tx in json["transactions"]:
            transactions.append(bytes.fromhex(tx))

        return BlockBody(transactions, elements)
