#Types.
from typing import Dict, Tuple, Any

#Transaction and SpamFilter classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#Data class.
class Data(
    Transaction
):
    #Constructor.
    def __init__(
        self,
        txInput: bytes,
        data: bytes,
        signature: bytes = bytes(64),
        proof: int = 0
    ) -> None:
        self.txInput: bytes = txInput
        self.data: bytes = data
        self.hash: bytes = blake2b(
            b"\3" + txInput + data,
            digest_size=32
        ).digest()

        self.signature: bytes = signature

        self.proof: int = proof
        self.argon: bytes = SpamFilter.run(self.hash, self.proof)

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
        spamFilter: SpamFilter
    ) -> None:
        result: Tuple[bytes, int] = spamFilter.beat(self.hash)
        self.argon = result[0]
        self.proof = result[1]

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.txInput +
            (len(self.data) - 1).to_bytes(1, "big") +
            self.data +
            self.signature +
            self.proof.to_bytes(4, "big")
        )

    #Data -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "Data",
            "inputs": [{
                "hash": self.txInput.hex().upper()
            }],
            "outputs": [],
            "hash": self.hash.hex().upper(),

            "data": self.data.hex().upper(),
            "signature": self.signature.hex().upper(),
            "proof": self.proof,
            "argon": self.argon.hex().upper()
        }

    #JSON -> Data.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Data(
            bytes.fromhex(json["inputs"][0]["hash"]),
            bytes.fromhex(json["data"]),
            bytes.fromhex(json["signature"]),
            json["proof"]
        )
