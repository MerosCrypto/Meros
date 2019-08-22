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
        self.prefix: bytes = b'\0'

        self.holder: bytes = holder
        self.nonce: int = nonce

        self.hash: bytes = hash

    #Element -> Verification. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #Serialize.
    def serialize(
        self
    ) -> bytes:
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
            "descendant": "Verification",
            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,

            "hash": self.hash.hex().upper()
        }

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
        if signature != bytes(96):
            self.blsSignature: blspy.Signature = blspy.Signature.from_bytes(self.signature)
            self.blsSignature.set_aggregation_info(
                blspy.AggregationInfo.from_msg(
                    blspy.PublicKey.from_bytes(holder),
                    self.prefix + Verification.serialize(self)
                )
            )

    #Sign.
    def sign(
        self,
        privKey: blspy.PrivateKey,
        nonce: int
    ) -> None:
        self.holder = privKey.get_public_key().serialize()
        self.nonce = nonce

        self.blsSignature = privKey.sign(self.prefix + Verification.serialize(self))
        self.signature = self.blsSignature.serialize()

    #Serialize.
    def signedSerialize(
        self
    ) -> bytes:
        return (
            Verification.serialize(self) +
            self.signature
        )

    #SignedVerification -> SignedElement.
    def toSignedElement(
        self
    ) -> Any:
        return self

    #SignedVerification -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "Verification",

            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,

            "hash": self.hash.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> Verification.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return SignedVerification(
            bytes.fromhex(json["hash"]),
            bytes.fromhex(json["holder"]),
            json["nonce"],
            bytes.fromhex(json["signature"])
        )
