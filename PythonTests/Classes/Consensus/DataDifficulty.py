#Types.
from typing import Dict, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, Signature

#Element classes.
from PythonTests.Classes.Consensus.Element import Element, SignedElement

#DataDifficulty Prefix.
DATA_DIFFICULTY_PREFIX: bytes = b'\3'

#DataDifficulty class.
class DataDifficulty(
    Element
):
    #Constructor.
    def __init__(
        self,
        difficulty: int,
        nonce: int,
        holder: int
    ) -> None:
        self.prefix: bytes = DATA_DIFFICULTY_PREFIX

        self.difficulty: int = difficulty
        self.nonce: int = nonce
        self.holder: int = holder

    #Serialize for signing.
    def signatureSerialize(
        self
    ) -> bytes:
        return DATA_DIFFICULTY_PREFIX + self.nonce.to_bytes(4, "big") + self.difficulty.to_bytes(4, "big")

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return self.holder.to_bytes(2, "big") + self.nonce.to_bytes(4, "big") + self.difficulty.to_bytes(4, "big")

    #DataDifficulty -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "DataDifficulty",

            "difficulty": self.difficulty,
            "nonce": self.nonce,
            "holder": self.holder
        }

    #JSON -> DataDifficulty.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return DataDifficulty(json["difficulty"], json["nonce"], json["holder"])

class SignedDataDifficulty(
    SignedElement,
    DataDifficulty
):
    #Constructor.
    def __init__(
        self,
        difficulty: int,
        nonce: int = 0,
        holder: int = 0,
        signature: Signature = Signature()
    ) -> None:
        DataDifficulty.__init__(self, difficulty, nonce, holder)
        self.signature: Signature = signature

    #Sign.
    def sign(
        self,
        holder: int,
        privKey: PrivateKey
    ) -> None:
        self.holder = holder
        self.signature = privKey.sign(self.signatureSerialize())

    #Serialize.
    #pylint: disable=unused-argument
    def signedSerialize(
        self
    ) -> bytes:
        return DataDifficulty.serialize(self) + self.signature.serialize()

    #SignedDataDifficulty -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "DataDifficulty",

            "holder": self.holder,
            "nonce": self.nonce,
            "difficulty": self.difficulty,

            "signed": True,
            "signature": self.signature.serialize().hex().upper()
        }

    #JSON -> SignedDataDifficulty.
    @staticmethod
    def fromSignedJSON(
        json: Dict[str, Any]
    ) -> Any:
        return SignedDataDifficulty(
            json["difficulty"],
            json["nonce"],
            json["holder"],
            Signature(bytes.fromhex(json["signature"]))
        )
