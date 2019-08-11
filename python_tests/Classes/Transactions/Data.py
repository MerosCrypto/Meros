#Types.
from typing import Dict, Tuple, Any

#Transaction and SpamFilter classes.
from python_tests.Classes.Transactions.Transaction import Transaction
from python_tests.Classes.Consensus.SpamFilter import SpamFilter

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#Data class.
class Data(Transaction):
    #Constructor.
    def __init__(
        self,
        input: bytes,
        data: bytes,
        signature: bytes = bytes(64),
        proof: int = 0
    ) -> None:
        self.input: bytes = input
        self.data: bytes = data
        self.hash: bytes = blake2b(
            b"\3" + input + data,
            digest_size = 48
        ).digest()

        self.signature: bytes = signature

        self.proof: int = proof
        self.argon: bytes = SpamFilter.run(self.hash, self.proof)
        self.verified: bool = False

    #Transaction -> Data. Satisifes static typing requirements.
    @staticmethod
    def fromTransaction(
        tx: Transaction
    ) -> Any:
        return tx

    #Sign.
    def sign(
        self,
        privKey: ed25519.SigningKey
    ) -> None:
        self.signature = privKey.sign(b"MEROS" + self.hash)

    #Mine.
    def beat(
        self,
        filter: SpamFilter
    ) -> None:
        result: Tuple[bytes, int] = filter.beat(self.hash)
        self.argon = result[0]
        self.proof = result[1]

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.input +
            len(self.data).to_bytes(1, byteorder = "big") +
            self.data +
            self.signature +
            self.proof.to_bytes(4, byteorder = "big")
        )

    #Data -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "Data",
            "inputs": [
                {
                    "hash": self.input.hex().upper()
                }
            ],
            "outputs": [],
            "hash": self.hash.hex().upper(),

            "data": self.data.hex().upper(),
            "signature": self.signature.hex().upper(),
            "proof": self.proof,
            "argon": self.argon.hex().upper(),

            "verified": self.verified
        }

    #JSON -> Data.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        result: Data = Data(
            bytes.fromhex(json["inputs"][0]["hash"]),
            bytes.fromhex(json["data"]),
            bytes.fromhex(json["signature"]),
            json["proof"]
        )
        if json["verified"]:
            result.verified = True
        return result
