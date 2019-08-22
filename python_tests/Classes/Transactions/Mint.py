#Types.
from typing import Dict, Tuple, Any

#Transaction and SpamFilter classes.
from python_tests.Classes.Transactions.Transaction import Transaction

#BLS lib.
import blspy

#Blake2b standard function.
from hashlib import blake2b

#Mint class.
class Mint(Transaction):
    #Constructor.
    def __init__(
        self,
        nonce: int,
        output: Tuple[blspy.PublicKey, int]
    ) -> None:
        self.nonce: int = nonce
        self.output: Tuple[blspy.PublicKey, int] = output
        self.hash = blake2b(b'\0' + self.nonce.to_bytes(4, byteorder = "big") + self.output[0].serialize() + self.output[1].to_bytes(8, byteorder = "big"), digest_size = 48).digest()
        self.verified: bool = True

    #Transaction -> Mint. Satisifes static typing requirements.
    @staticmethod
    def fromTransaction(
        tx: Transaction
    ) -> Any:
        return tx

    #Mint -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "descendant": "Mint",
            "inputs": [],
            "outputs": [{
                "key": self.output[0].serialize().hex().upper(),
                "amount": str(self.output[1])
            }],
            "hash": self.hash.hex().upper(),

            "nonce": self.nonce,

            "verified": self.verified
        }
        return result

    #JSON -> Mint.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Mint(
            json["nonce"],
            (
                blspy.PublicKey.from_bytes(bytes.fromhex(json["outputs"][0]["key"])),
                int(json["outputs"][1])
            ),
        )
