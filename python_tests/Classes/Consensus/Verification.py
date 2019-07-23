#Types.
from typing import Dict, Any

#Element class.
from python_tests.Classes.Consensus.Element import Element

#BLS lib.
import blspy

#Verification class.
class Verification(Element):
    #Constructor.
    def __init__(
        self,
        holder: bytes,
        nonce: int,
        hash: bytes
    ) -> None:
        self.holder: bytes = holder
        self.hash: bytes = hash
        self.nonce: int = nonce

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        #the 48-byte holder, the 4-byte nonce, and the 48-byte hash. The signature is produced with a prefix of "\0".
        return (
            self.holder +
            self.nonce.to_bytes(4, byteorder = "big") +
            self.hash
        )

    #Verification -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "verification",
            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,

            "hash": self.hash.hex().upper()
        }

    #Element -> Verification. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #JSON -> Verification.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Verification(
            bytes.fromhex(json["holder"]),
            json["nonce"],
            bytes.fromhex(json["hash"])
        )

class SignedVerification(Verification):
    #Constructor.
    def __init__(
        self,
        hash: bytes,
        holder: bytes = bytes(48),
        nonce: int = 0,
        signature: bytes = bytes(96)
    ) -> None:
        Verification.__init__(self, holder, nonce, hash)
        self.signature: bytes = signature

    #Sign.
    def sign(
        self,
        privKey: blspy.PrivateKey,
        nonce: int
    ) -> None:
        self.holder = privKey.get_public_key().serialize()
        self.nonce = nonce
        self.signature = privKey.sign(b'\0' + Verification.serialize(self)).serialize()

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        #the 48-byte holder, the 4-byte nonce, and the 48-byte hash. The signature is produced with a prefix of "\0".
        return (
            self.holder +
            self.nonce.to_bytes(4, byteorder = "big") +
            self.hash +
            self.signature
        )
