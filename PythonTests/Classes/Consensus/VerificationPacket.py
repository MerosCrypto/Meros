#Types.
from typing import Dict, List, Any

#Element class.
from PythonTests.Classes.Consensus.Element import Element

#VerificationPacket class.
class VerificationPacket(Element):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holders: List[int]
    ) -> None:
        self.prefix: bytes = b'\1'

        self.hash: bytes = txHash
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
        for holder in self.holders:
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

class SignedVerificationPacket(VerificationPacket):
    #Constructor.
    def __init__(
        self,
        txHash: bytes,
        holders: List[int],
        signature: bytes = bytes(96)
    ) -> None:
        VerificationPacket.__init__(self, txHash, holders)
        self.signature: bytes = signature

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
            "hash": self.hash.hex().upper(),

            "signed": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> VerificationPacket.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return SignedVerificationPacket(
            bytes.fromhex(json["hash"]),
            json["holders"],
            bytes.fromhex(json["signature"])
        )
