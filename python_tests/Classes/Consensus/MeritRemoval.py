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
        nonce: int,
        e1: Element,
        e2: Element
    ) -> None:
        self.holder: bytes = e1.holder
        self.nonce: int = nonce

        self.e1: Element = e1
        self.e2: Element = e2

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.holder +
            self.nonce.to_bytes(4, byteorder = "big") +
            self.e1.prefix +
            self.e1.serialize() +
            self.e2.prefix +
            self.e2.serialize()
        )

    #MeritRemoval -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "meritremoval",
            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,
            "elements": [
                self.e1.toJSON(),
                self.e2.toJSON()
            ]
        }

    #Element -> MeritRemoval. Satisifes static typing requirements.
    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    #JSON -> MeritRemoval.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        e1: Element = Element()
        if json["elements"][0].descendant == "verification":
            e1 = Verification.fromJSON(json["elements"][0])

        e2: Element = Element()
        if json["elements"][1].descendant == "verification":
            e2 = Verification.fromJSON(json["elements"][1])

        return MeritRemoval(
            json["nonce"],
            e1,
            e2
        )

class SignedMeritRemoval(MeritRemoval):
    #Constructor.
    def __init__(
        self,
        nonce: int,
        se1: SignedElement,
        se2: SignedElement
    ) -> None:
        MeritRemoval.__init__(self, nonce, se1, se2)

        self.se1: SignedElement = se1
        self.se2: SignedElement = se2
        self.blsSignature: blspy.Signature = blspy.Signature.aggregate([
            self.se1.blsSignature,
            self.se2.blsSignature
        ])
        self.signature = self.blsSignature.serialize()

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            MeritRemoval.serialize(self) +
            self.signature
        )

    #SignedMeritRemoval -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "meritremoval",
            "holder": self.holder.hex().upper(),
            "nonce": self.nonce,
            "elements": [
                self.se1.toSignedJSON(),
                self.se2.toSignedJSON()
            ],
            "signature": self.signature.hex().upper()
        }

    #JSON -> MeritRemoval.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        e1: SignedElement = SignedElement()
        if json["elements"][0].descendant == "verification":
            e1 = SignedVerification.fromJSON(json["elements"][0])

        e2: SignedElement = SignedElement()
        if json["elements"][1].descendant == "verification":
            e2 = SignedVerification.fromJSON(json["elements"][1])

        return SignedMeritRemoval(
            json["nonce"],
            e1,
            e2
        )
