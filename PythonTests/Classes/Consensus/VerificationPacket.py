#Types.
from typing import Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import Signature

#Element classes.
from PythonTests.Classes.Consensus.Element import Element, SignedElement

#SignedVerification class.
from PythonTests.Classes.Consensus.Verification import SignedVerification

#VerificationPacket Prefix.
VERIFICATION_PACKET_PREFIX: bytes = b'\1'

#VerificationPacket class.
class VerificationPacket(
    Element
):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holders: List[int]
    ) -> None:
        self.prefix: bytes = VERIFICATION_PACKET_PREFIX

        self.hash: bytes = txHash
        self.holders: List[int] = holders

    #'Signature' serialize. Used by MeritRemovals.
    def signatureSerialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        result: bytes = self.prefix + len(self.holders).to_bytes(2, "big")
        for holder in self.holders:
            result += lookup[holder]
        result += self.hash

        return result

    #Serialize.
    def serialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        result: bytes = len(self.holders).to_bytes(2, "big")
        for holder in sorted(self.holders):
            result += holder.to_bytes(2, "big")
        result += self.hash
        return result

    #VerificationPacket -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "VerificationPacket",

            "hash": self.hash.hex().upper(),
            "holders": self.holders
        }

    #JSON -> VerificationPacket.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return VerificationPacket(bytes.fromhex(json["hash"]), json["holders"])

class SignedVerificationPacket(
    SignedElement,
    VerificationPacket
):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holders: List[int] = [],
        signature: Signature = Signature()
    ) -> None:
        VerificationPacket.__init__(self, txHash, holders)
        self.signature: Signature = signature

    #Add a SignedVerification.
    def add(
        self,
        verif: SignedVerification
    ) -> None:
        self.holders.append(verif.holder)

        if self.signature.isInf():
            self.signature = verif.signature
        else:
            self.signature = Signature.aggregate([self.signature, verif.signature])

    #Serialize.
    def signedSerialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        return VerificationPacket.serialize(self) + self.signature.serialize()

    #SignedVerificationPacket -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "VerificationPacket",

            "holders": self.holders,
            "hash": self.hash.hex().upper(),

            "signed": True,
            "signature": self.signature.serialize().hex().upper()
        }

    #JSON -> SignedVerificationPacket.
    @staticmethod
    def fromSignedJSON(
        json: Dict[str, Any]
    ) -> Any:
        return SignedVerificationPacket(
            bytes.fromhex(json["hash"]),
            json["holders"],
            Signature(bytes.fromhex(json["signature"]))
        )
