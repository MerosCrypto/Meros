#Types.
from typing import Dict, Any

#BLS lib.
import blspy

#Element root class.
class Element:
    prefix: bytes

    holder: bytes
    nonce: int

    def serialize(
        self
    ) -> bytes:
        raise Exception("Base Element serialize called.")

    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Element toJSON called.")

#SignedElement helper class.
class SignedElement(Element):
    blsSignature: blspy.Signature

    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    def signedSerialize(
        self
    ) -> bytes:
        raise Exception("Base SignedElement serialize called.")

    #SignedElement -> JSON.
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base SignedElement toSignedJSON called.")
