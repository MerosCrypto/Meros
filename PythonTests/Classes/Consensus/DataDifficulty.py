#Types.
from typing import Dict, List, Optional, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#DataDifficulty Prefix.
DATA_DIFFICULTY_PREFIX: bytes = b'\3'

#DataDifficulty class.
class DataDifficulty(Element):
    #Constructor.
    def __init__(
        self,
        difficulty: bytes,
        nonce: int,
        holder: int
    ) -> None:
        self.prefix: bytes = DATA_DIFFICULTY_PREFIX

        self.difficulty: bytes = difficulty
        self.nonce: int = nonce
        self.holder: int = holder

    #Element -> DataDifficulty. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #Serialize for signing.
    def signatureSerialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        return DATA_DIFFICULTY_PREFIX + self.nonce.to_bytes(4, "big") + self.difficulty

    #Serialize.
    def serialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        return self.holder.to_bytes(2, "big") + self.nonce.to_bytes(4, "big") + self.difficulty

    #DataDifficulty -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "DataDifficulty",

            "difficulty": self.difficulty.hex().upper(),
            "nonce": self.nonce,
            "holder": self.holder
        }

    #JSON -> DataDifficulty.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return DataDifficulty(bytes.fromhex(json["difficulty"]), json["nonce"], json["holder"])

class SignedDataDifficulty(DataDifficulty):
    #Constructor.
    def __init__(
        self,
        difficulty: bytes,
        nonce: int = 0,
        holder: int = 0,
        holderKey: Optional[PublicKey] = None,
        signature: bytes = Signature().serialize()
    ) -> None:
        DataDifficulty.__init__(self, difficulty, nonce, holder)
        self.signature: bytes = signature

        self.blsSignature: Signature
        if holderKey:
            self.blsSignature = Signature(self.signature)

    #Sign.
    def sign(
        self,
        holder: int,
        privKey: PrivateKey
    ) -> None:
        self.holder = holder
        self.blsSignature = privKey.sign(self.signatureSerialize())
        self.signature = self.blsSignature.serialize()

    #Serialize.
    #pylint: disable=unused-argument
    def signedSerialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        return DataDifficulty.serialize(self) + self.signature

    #SignedDataDifficulty -> SignedElement.
    def toSignedElement(
        self
    ) -> Any:
        return self

    #SignedDataDifficulty -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "DataDifficulty",

            "holder": self.holder,
            "nonce": self.nonce,
            "difficulty": self.difficulty.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> SignedDataDifficulty.
    @staticmethod
    def fromSignedJSON(
        nicks: List[bytes],
        json: Dict[str, Any]
    ) -> Any:
        return SignedDataDifficulty(
            bytes.fromhex(json["difficulty"]),
            json["nonce"],
            json["holder"],
            PublicKey(nicks[json["holder"]]),
            bytes.fromhex(json["signature"])
        )
