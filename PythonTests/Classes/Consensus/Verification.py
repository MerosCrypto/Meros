#Types.
from typing import Dict, List, Optional, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#Verification Prefix.
VERIFICATION_PREFIX: bytes = b'\0'

#Verification class.
class Verification(Element):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holder: int
    ) -> None:
        self.prefix: bytes = VERIFICATION_PREFIX

        self.hash: bytes = txHash
        self.holder: int = holder

    #Element -> Verification. Satisifes static typing requirements.
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
        return self.prefix + self.hash

    #Serialize.
    def serialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        return self.holder.to_bytes(2, "big") + self.hash

    #Verification -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "Verification",

            "hash": self.hash.hex().upper(),
            "holder": self.holder
        }

    #JSON -> Verification.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Verification(bytes.fromhex(json["hash"]), json["holder"])

class SignedVerification(Verification):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holder: int = 0,
        holderKey: Optional[PublicKey] = None,
        signature: bytes = Signature().serialize()
    ) -> None:
        Verification.__init__(self, txHash, holder)
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
            "hash": self.hash.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> SignedVerification.
    @staticmethod
    def fromSignedJSON(
        nicks: List[bytes],
        json: Dict[str, Any]
    ) -> Any:
        return SignedVerification(
            bytes.fromhex(json["hash"]),
            json["holder"],
            PublicKey(nicks[json["holder"]]),
            bytes.fromhex(json["signature"])
        )
