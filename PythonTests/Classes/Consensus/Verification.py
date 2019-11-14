#Types.
from typing import Dict, Optional, Any

#State class.
from PythonTests.Classes.Merit.State import State

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#BLS lib.
from blspy import PrivateKey, PublicKey, Signature, AggregationInfo

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

        self.txHash: bytes = txHash
        self.holder: int = holder

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
        return self.holder.to_bytes(2, "big") + self.txHash

    #Verification -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "Verification",

            "hash": self.txHash.hex().upper(),
            "holder": self.holder
        }

    #JSON -> Verification.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Verification(bytes.fromhex(json["hash"]), json["holder"])

class SignedVerification(Verification):
    #Serialize for signing.
    @staticmethod
    def signatureSerialize(
        txHash: bytes
    ) -> bytes:
        return VERIFICATION_PREFIX + txHash

    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holder: int = 0,
        holderKey: Optional[PublicKey] = None,
        signature: bytes = bytes(96)
    ) -> None:
        Verification.__init__(self, txHash, holder)
        self.signature: bytes = signature

        self.blsSignature: Signature
        if holderKey:
            self.blsSignature = Signature.from_bytes(self.signature)
            self.blsSignature.set_aggregation_info(
                AggregationInfo.from_msg(
                    holderKey,
                    SignedVerification.signatureSerialize(self.txHash)
                )
            )
    #Sign.
    def sign(
        self,
        holder: int,
        privKey: PrivateKey
    ) -> None:
        self.holder = holder
        self.blsSignature = privKey.sign(SignedVerification.signatureSerialize(self.txHash))
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
            "hash": self.txHash.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> SignedVerification.
    @staticmethod
    def fromSignedJSON(
        state: State,
        json: Dict[str, Any]
    ) -> Any:
        return SignedVerification(
            bytes.fromhex(json["hash"]),
            json["holder"],
            PublicKey.from_bytes(state.nicks[json["holder"]]),
            bytes.fromhex(json["signature"])
        )
