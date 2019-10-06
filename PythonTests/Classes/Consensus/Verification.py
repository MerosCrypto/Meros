#Types.
from typing import Dict, Any

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#BLS lib.
import blspy

#Verification class.
class Verification(Element):
    #Constructor.
    def __init__(
        self,
        holder: int,
        txHash: bytes
    ) -> None:
        self.prefix: bytes = b'\0'

        self.holder: int = holder
        self.hash: bytes = txHash

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
        return self.holder.to_bytes(2, "big") + self.hash

    #Verification -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "Verification",

            "holder": self.holder,
            "hash": self.hash.hex().upper()
        }

    #JSON -> Verification.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Verification(json["holder"], bytes.fromhex(json["hash"]))

class SignedVerification(Verification):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holder: int = 0,
        holderKey: blspy.PublicKey = blspy.PrivateKey.from_seed(b'\0').get_public_key(),
        signature: bytes = bytes(96)
    ) -> None:
        Verification.__init__(self, holder, txHash)
        self.holderKey: blspy.PublicKey = holderKey

        self.signature: bytes = signature
        if signature != bytes(96):
            self.blsSignature: blspy.Signature = blspy.Signature.from_bytes(self.signature)
            self.blsSignature.set_aggregation_info(
                blspy.AggregationInfo.from_msg(
                    holderKey,
                    self.prefix + Verification.serialize(self)
                )
            )

    #Sign.
    def sign(
        self,
        holder: int,
        privKey: blspy.PrivateKey
    ) -> None:
        self.holder = holder
        self.blsSignature = privKey.sign(self.prefix + self.hash)
        self.signature = self.blsSignature.serialize()

    #Serialize.
    def signedSerialize(
        self
    ) -> bytes:
        return Verification.serialize(self) + self.signature

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

            "holder": self.holder,
            "holderKey": self.holderKey.serialize().hex().upper(),
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
            json["holder"],
            blspy.PublicKey.from_bytes(bytes.fromhex(json["holderKey"])),
            bytes.fromhex(json["signature"])
        )
