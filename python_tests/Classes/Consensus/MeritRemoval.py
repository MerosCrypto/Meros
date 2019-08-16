#Types.
from typing import Dict, Any

#Element and Element descendant classes.
from python_tests.Classes.Consensus.Element import Element, SignedElement
from python_tests.Classes.Consensus.Verification import Verification, SignedVerification

#BLS lib.
import blspy

#MeritRemoval class.
class MeritRemoval(Element):
    #Constructor.
    def __init__(
        self,
        partial: bool,
        e1: Element,
        e2: Element
    ) -> None:
        self.prefix: bytes = b'\4'
        self.partial: bool = partial

        self.holder: bytes = e1.holder
        self.nonce: int = 0

        self.e1: Element = e1
        self.e2: Element = e2

    #Element -> MeritRemoval. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = self.holder

        if self.partial:
            result += b'\1'
        else:
            result += b'\0'

        result += (
            self.e1.prefix +
            self.e1.serialize()[48:] +
            self.e2.prefix +
            self.e2.serialize()[48:]
        )
        return result

    #MeritRemoval -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "MeritRemoval",

            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,

            "partial": self.partial,
            "elements": [
                self.e1.toJSON(),
                self.e2.toJSON()
            ]
        }

    #JSON -> MeritRemoval.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        e1: Element = Element()
        if json["elements"][0]["descendant"] == "Verification":
            e1 = Verification.fromJSON(json["elements"][0])

        e2: Element = Element()
        if json["elements"][1]["descendant"] == "Verification":
            e2 = Verification.fromJSON(json["elements"][1])

        result: MeritRemoval = MeritRemoval(
            json["partial"],
            e1,
            e2
        )
        result.nonce = json["nonce"]
        return result

class PartiallySignedMeritRemoval(MeritRemoval):
    #Constructor.
    def __init__(
        self,
        e1: Element,
        se2: SignedElement
    ) -> None:
        MeritRemoval.__init__(self, True, e1, se2)

        self.se2: SignedElement = se2
        self.blsSignature: blspy.Signature = self.se2.blsSignature
        self.signature: bytes = self.blsSignature.serialize()

    #PartiallySignedMeritRemoval -> SignedElement.
    def toSignedElement(
        self
    ) -> Any:
        return self

    #Serialize.
    def signedSerialize(
        self
    ) -> bytes:
        return (
            MeritRemoval.serialize(self) +
            self.signature
        )

    #PartiallySignedMeritRemoval -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "MeritRemoval",

            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,

            "elements": [
                self.e1.toJSON(),
                self.se2.toSignedJSON()
            ],

            "signed": True,
            "partial": True,
            "signature": self.signature.hex().upper()
        }

    #JSON -> MeritRemoval.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        e1: Element = Element()
        if json["elements"][0]["descendant"] == "Verification":
            e1 = Verification.fromJSON(json["elements"][0])
        else:
            raise Exception("MeritRemoval constructed from an unsupported type of Element: " + json["elements"][0]["descendant"])

        se2: SignedElement = SignedElement()
        if json["elements"][1]["descendant"] == "Verification":
            se2 = SignedVerification.fromJSON(json["elements"][1])
        else:
            raise Exception("MeritRemoval constructed from an unsupported type of Element: " + json["elements"][1]["descendant"])

        result: PartiallySignedMeritRemoval = PartiallySignedMeritRemoval(
            e1,
            se2
        )
        result.nonce = json["nonce"]
        return result

class SignedMeritRemoval(PartiallySignedMeritRemoval):
    #Constructor.
    def __init__(
        self,
        se1: SignedElement,
        se2: SignedElement
    ) -> None:
        MeritRemoval.__init__(self, False, se1, se2)

        self.se1: SignedElement = se1
        self.se2: SignedElement = se2
        self.blsSignature: blspy.Signature = blspy.Signature.aggregate([
            self.se1.blsSignature,
            self.se2.blsSignature
        ])
        self.signature: bytes = self.blsSignature.serialize()

    #SignedMeritRemoval -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "MeritRemoval",

            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,

            "elements": [
                self.se1.toSignedJSON(),
                self.se2.toSignedJSON()
            ],

            "signed": True,
            "partial": False,
            "signature": self.signature.hex().upper()
        }

    #JSON -> MeritRemoval.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        se1: SignedElement = SignedElement()
        if json["elements"][0]["descendant"] == "Verification":
            se1 = SignedVerification.fromJSON(json["elements"][0])
        else:
            raise Exception("MeritRemoval constructed from an unsupported type of Element: " + json["elements"][0]["descendant"])

        se2: SignedElement = SignedElement()
        if json["elements"][1]["descendant"] == "Verification":
            se2 = SignedVerification.fromJSON(json["elements"][1])
        else:
            raise Exception("MeritRemoval constructed from an unsupported type of Element: " + json["elements"][1]["descendant"])

        result: SignedMeritRemoval = SignedMeritRemoval(
            se1,
            se2
        )
        result.nonce = json["nonce"]
        return result
