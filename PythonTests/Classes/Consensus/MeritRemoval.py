#Types.
from typing import Dict, List, Any

#Element classes.
from PythonTests.Classes.Consensus.Element import Element, SignedElement
from PythonTests.Classes.Consensus.Verification import Verification, SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket, SignedVerificationPacket
from PythonTests.Classes.Consensus.SendDifficulty import SendDifficulty, SignedSendDifficulty
from PythonTests.Classes.Consensus.DataDifficulty import DataDifficulty, SignedDataDifficulty

#MeritRemoval Prefix.
MERIT_REMOVAL_PREFIX: bytes = b'\5'

#MeritRemoval class.
class MeritRemoval(Element):
    #Constructor.
    def __init__(
        self,
        e1: Element,
        e2: Element,
        partial: bool
    ) -> None:
        self.prefix: bytes = MERIT_REMOVAL_PREFIX

        self.e1: Element = e1
        self.e2: Element = e2
        self.partial: bool = partial
        self.holder: int = self.e1.holder

    #Element -> MeritRemoval. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #Signature Serialize.
    def signatureSerialize(
        self,
        lookup: List[bytes] = []
    ) -> bytes:
        raise Exception("MeritRemoval's signatureSerialize was called.")

    #Serialize.
    def serialize(
        self,
        lookup: List[bytes]
    ) -> bytes:
        return (
            self.holder.to_bytes(2, "big") +
            (b'\1' if self.partial else b'\0') +
            self.e1.signatureSerialize(lookup) +
            self.e2.signatureSerialize(lookup)
        )

    #DataDifficulty -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "descendant": "MeritRemoval",

            "holder": self.holder,
            "partial": self.partial,
            "elements": [self.e1.toJSON(), self.e2.toJSON()]
        }

        del result["elements"][0]["holder"]
        del result["elements"][1]["holder"]

        return result

    #JSON -> MeritRemoval.
    @staticmethod
    def fromJSON(
        keys: Dict[bytes, int],
        jsonArg: Dict[str, Any]
    ) -> Any:
        json: Dict[str, Any] = dict(jsonArg)
        json["elements"] = list(json["elements"])
        json["elements"][0] = dict(json["elements"][0])
        json["elements"][1] = dict(json["elements"][1])

        json["elements"][0]["holder"] = json["holder"]
        json["elements"][1]["holder"] = json["holder"]

        e1: Element = Verification(bytes(32), 0)
        if json["elements"][0]["descendant"] == "Verification":
            e1 = Verification.fromJSON(json["elements"][0])
        elif json["elements"][0]["descendant"] == "VerificationPacket":
            json["elements"][0]["holders"] = list(json["elements"][0]["holders"])
            for h in range(len(json["elements"][0]["holders"])):
                json["elements"][0]["holders"][h] = keys[bytes.fromhex(json["elements"][0]["holders"][h])]
            e1 = VerificationPacket.fromJSON(json["elements"][0])
        elif json["elements"][0]["descendant"] == "SendDifficulty":
            e1 = SendDifficulty.fromJSON(json["elements"][0])
        elif json["elements"][0]["descendant"] == "DataDifficulty":
            e1 = DataDifficulty.fromJSON(json["elements"][0])
        else:
            raise Exception("Unknown Element used to construct a MeritRemoval.")

        e2: Element = Verification(bytes(32), 0)
        if json["elements"][1]["descendant"] == "Verification":
            e2 = Verification.fromJSON(json["elements"][1])
        elif json["elements"][1]["descendant"] == "VerificationPacket":
            json["elements"][1]["holders"] = list(json["elements"][1]["holders"])
            for h in range(len(json["elements"][1]["holders"])):
                json["elements"][1]["holders"][h] = keys[bytes.fromhex(json["elements"][1]["holders"][h])]
            e2 = VerificationPacket.fromJSON(json["elements"][1])
        elif json["elements"][1]["descendant"] == "SendDifficulty":
            e2 = SendDifficulty.fromJSON(json["elements"][1])
        elif json["elements"][1]["descendant"] == "DataDifficulty":
            e2 = DataDifficulty.fromJSON(json["elements"][1])
        else:
            raise Exception("Unknown Element used to construct a MeritRemoval.")

        return MeritRemoval(e1, e2, json["partial"])

class PartialMeritRemoval(MeritRemoval):
    #Constructor.
    def __init__(
        self,
        e1: Element,
        e2: SignedElement
    ) -> None:
        MeritRemoval.__init__(self, e1, e2, True)

        self.se2: SignedElement = e2
        self.signature: bytes = e2.signature

    #Signed Serialize.
    def signedSerialize(
        self,
        lookup: List[bytes]
    ) -> bytes:
        return MeritRemoval.serialize(self, lookup) + self.signature

    #SignedDataDifficulty -> SignedElement.
    def toSignedElement(
        self
    ) -> Any:
        return self

    #SignedDataDifficulty -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = MeritRemoval.toJSON(self)
        result["signed"] = True
        result["signature"] = self.signature.hex().upper()
        return result

    #JSON -> SignedDataDifficulty.
    @staticmethod
    def fromSignedJSON(
        keys: Dict[bytes, int],
        jsonArg: Dict[str, Any]
    ) -> Any:
        json: Dict[str, Any] = dict(jsonArg)
        json["elements"] = list(json["elements"])
        json["elements"][0] = dict(json["elements"][0])
        json["elements"][1] = dict(json["elements"][1])

        json["elements"][0]["holder"] = json["holder"]
        json["elements"][1]["holder"] = json["holder"]

        e1: Element = Verification(bytes(32), 0)
        if json["elements"][0]["descendant"] == "Verification":
            e1 = Verification.fromJSON(json["elements"][0])
        elif json["elements"][0]["descendant"] == "VerificationPacket":
            json["elements"][0]["holders"] = list(json["elements"][0]["holders"])
            for h in range(len(json["elements"][0]["holders"])):
                json["elements"][0]["holders"][h] = keys[bytes.fromhex(json["elements"][0]["holders"][h])]
            e1 = VerificationPacket.fromJSON(json["elements"][0])
        elif json["elements"][0]["descendant"] == "SendDifficulty":
            e1 = SendDifficulty.fromJSON(json["elements"][0])
        elif json["elements"][0]["descendant"] == "DataDifficulty":
            e1 = DataDifficulty.fromJSON(json["elements"][0])

        e2: SignedElement = SignedVerification(bytes(32), 0).toSignedElement()
        if json["elements"][1]["descendant"] == "Verification":
            e2 = SignedVerification.fromJSON(json["elements"][1])
        elif json["elements"][1]["descendant"] == "VerificationPacket":
            json["elements"][1]["holders"] = list(json["elements"][1]["holders"])
            for h in range(len(json["elements"][1]["holders"])):
                json["elements"][1]["holders"][h] = keys[bytes.fromhex(json["elements"][1]["holders"][h])]
            e2 = SignedVerificationPacket.fromJSON(json["elements"][1])
        elif json["elements"][1]["descendant"] == "SendDifficulty":
            e2 = SignedSendDifficulty.fromJSON(json["h"][1])
        elif json["elements"][1]["descendant"] == "DataDifficulty":
            e2 = SignedDataDifficulty.fromJSON(json["elements"][1])

        return PartialMeritRemoval(e1, e2)
