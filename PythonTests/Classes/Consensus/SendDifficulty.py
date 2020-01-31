#Types.
from typing import Dict, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, Signature

#Element class.
from PythonTests.Classes.Consensus.Element import Element, SignedElement

#SendDifficulty Prefix.
SEND_DIFFICULTY_PREFIX: bytes = b'\2'

#SendDifficulty class.
class SendDifficulty(
    Element
):
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

    #Serialize for signing.
    def signatureSerialize(
        self
    ) -> bytes:
        return SEND_DIFFICULTY_PREFIX + self.nonce.to_bytes(4, "big") + self.difficulty

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

class SignedSendDifficulty(
    SignedElement,
    SendDifficulty
):
    #Constructor.
    def __init__(
        self,
        difficulty: bytes,
        nonce: int = 0,
        holder: int = 0,
        signature: Signature = Signature()
    ) -> None:
        SendDifficulty.__init__(self, difficulty, nonce, holder)
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
        return SendDifficulty.serialize(self) + self.signature.serialize()

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
            "signature": self.signature.serialize().hex().upper()
        }

    #JSON -> SignedSendDifficulty.
    @staticmethod
    def fromSignedJSON(
        json: Dict[str, Any]
    ) -> Any:
        return SignedSendDifficulty(
            bytes.fromhex(json["difficulty"]),
            json["nonce"],
            json["holder"],
            Signature(bytes.fromhex(json["signature"]))
        )
