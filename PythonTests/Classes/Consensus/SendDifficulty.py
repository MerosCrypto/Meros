#Types.
from typing import Dict, List, Optional, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#SendDifficulty Prefix.
SEND_DIFFICULTY_PREFIX: bytes = b'\2'

#SendDifficulty class.
class SendDifficulty(Element):
    #Constructor.
    def __init__(
        self,
        difficulty: bytes,
        nonce: int,
        holder: int
    ) -> None:
        self.prefix: bytes = SEND_DIFFICULTY_PREFIX

        self.difficulty: bytes = difficulty
        self.nonce: int = nonce
        self.holder: int = holder

    #Element -> SendDifficulty. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return self.holder.to_bytes(2, "big") + self.nonce.to_bytes(4, "big") + self.difficulty

    #SendDifficulty -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "SendDifficulty",

            "difficulty": self.difficulty.hex().upper(),
            "nonce": self.nonce,
            "holder": self.holder
        }

    #JSON -> SendDifficulty.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return SendDifficulty(bytes.fromhex(json["difficulty"]), json["nonce"], json["holder"])

class SignedSendDifficulty(SendDifficulty):
    #Serialize for signing.
    @staticmethod
    def signatureSerialize(
        difficulty: bytes,
        nonce: int
    ) -> bytes:
        return SEND_DIFFICULTY_PREFIX + nonce.to_bytes(4, "big") + difficulty

    #Constructor.
    def __init__(
        self,
        difficulty: bytes,
        nonce: int = 0,
        holder: int = 0,
        holderKey: Optional[PublicKey] = None,
        signature: bytes = Signature().serialize()
    ) -> None:
        SendDifficulty.__init__(self, difficulty, nonce, holder)
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
        self.blsSignature = privKey.sign(SignedSendDifficulty.signatureSerialize(self.difficulty, self.nonce))
        self.signature = self.blsSignature.serialize()

    #Serialize.
    def signedSerialize(
        self
    ) -> bytes:
        return SendDifficulty.serialize(self) + self.signature

    #SignedSendDifficulty -> SignedElement.
    def toSignedElement(
        self
    ) -> Any:
        return self

    #SignedSendDifficulty -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "SendDifficulty",

            "holder": self.holder,
            "nonce": self.nonce,
            "difficulty": self.difficulty.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> SignedSendDifficulty.
    @staticmethod
    def fromSignedJSON(
        nicks: List[bytes],
        json: Dict[str, Any]
    ) -> Any:
        return SignedSendDifficulty(
            bytes.fromhex(json["difficulty"]),
            json["nonce"],
            json["holder"],
            PublicKey(nicks[json["holder"]]),
            bytes.fromhex(json["signature"])
        )
