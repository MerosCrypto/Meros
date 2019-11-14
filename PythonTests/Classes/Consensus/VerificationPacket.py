#Types.
from typing import Dict, List, Optional, Any

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#SignedVerification class.
from PythonTests.Classes.Consensus.Verification import SignedVerification

#BLS lib.
from blspy import PublicKey, Signature, AggregationInfo

#VerificationPacket Prefix.
VERIFICATION_PACKET_PREFIX: bytes = b'\1'

#VerificationPacket class.
class VerificationPacket(Element):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holders: List[int]
    ) -> None:
        self.prefix: bytes = VERIFICATION_PACKET_PREFIX

        self.txHash: bytes = txHash
        self.holders: List[int] = holders

    #Element -> VerificationPacket. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = len(self.holders).to_bytes(1, "big")
        for holder in sorted(self.holders):
            result += holder.to_bytes(2, "big")
        result += self.txHash
        return result

    #Serialize for inclusion in the contents Merkle.
    def serializeContents(
        self
    ) -> bytes:
        return self.prefix + self.serialize()

    #VerificationPacket -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "VerificationPacket",

            "hash": self.txHash.hex().upper(),
            "holders": self.holders
        }

    #JSON -> VerificationPacket.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return VerificationPacket(bytes.fromhex(json["hash"]), json["holders"])

class SignedVerificationPacket(VerificationPacket):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holders: List[int] = [],
        holderKeys: Optional[List[PublicKey]] = None,
        signature: bytes = bytes(96)
    ) -> None:
        VerificationPacket.__init__(self, txHash, holders)
        self.signature: bytes = signature

        self.blsSignature: Signature
        if holderKeys:
            serialized: bytes = SignedVerification.signatureSerialize(self.txHash)

            self.blsSignature = Signature.from_bytes(signature)
            agInfo: AggregationInfo = AggregationInfo.from_msg(holderKeys[0], serialized)

            for h in range(1, len(self.holders)):
                agInfo = AggregationInfo.merge_infos([
                    agInfo,
                    AggregationInfo.from_msg(holderKeys[h], serialized)
                ])

    #Add a SignedVerification.
    def add(
        self,
        verif: SignedVerification
    ) -> None:
        self.holders.append(verif.holder)

        if self.signature == bytes(96):
            self.blsSignature = verif.blsSignature
        else:
            self.blsSignature = Signature.aggregate([self.blsSignature, verif.blsSignature])
        self.signature = self.blsSignature.serialize()

    #Serialize.
    def signedSerialize(
        self
    ) -> bytes:
        return VerificationPacket.serialize(self) + self.signature

    #SignedVerificationPacket -> SignedElement.
    def toSignedElement(
        self
    ) -> Any:
        return self

    #SignedVerificationPacket -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "VerificationPacket",

            "holders": self.holders,
            "hash": self.txHash.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> SignedVerificationPacket.
    @staticmethod
    def fromSignedJSON(
        nicks: List[bytes],
        json: Dict[str, Any]
    ) -> Any:
        holderKeys: List[PublicKey] = []
        for holder in json["holders"]:
            holderKeys.append(PublicKey.from_bytes(nicks[holder]))

        return SignedVerificationPacket(
            bytes.fromhex(json["hash"]),
            json["holders"],
            holderKeys,
            bytes.fromhex(json["signature"])
        )
