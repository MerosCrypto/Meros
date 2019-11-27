#Types.
from typing import Dict, Tuple, Any

#Transaction and SpamFilter classes.
from PythonTests.Classes.Transactions.Transaction import Transaction

#Blake2b standard function.
from hashlib import blake2b

#Mint class.
class Mint(Transaction):
    #Constructor.
    def __init__(
        self,
        nonce: int,
        output: Tuple[int, int]
    ) -> None:
        self.nonce: int = nonce
        self.output: Tuple[int, int] = output
        self.hash = blake2b(
            b'\0' +
            self.nonce.to_bytes(4, "big") +
            self.output[0].to_bytes(2, "big") +
            self.output[1].to_bytes(8, "big"),
            digest_size=48
        ).digest()

    #Transaction -> Mint. Satisifes static typing requirements.
    @staticmethod
    def fromTransaction(
        tx: Transaction
    ) -> Any:
        return tx

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        raise Exception("Mint serialize called.")

    #Mint -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "descendant": "Mint",
            "inputs": [],
            "outputs": [{
                "key": self.output[0],
                "amount": str(self.output[1])
            }],
            "hash": self.hash.hex().upper(),

            "nonce": self.nonce
        }
        return result

    #JSON -> Mint.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Mint(
            json["nonce"],
            (json["outputs"][0]["key"], int(json["outputs"][1])),
        )
