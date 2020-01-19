#pylint: disable=no-self-use

#Types.
from typing import Dict, List, Any

#Abstract class standard lib.
from abc import ABC, abstractmethod

#Element root class.
class Element(ABC):
    prefix: bytes
    holder: int

    @abstractmethod
    def signatureSerialize(
        self,
        lookup: List[bytes]
    ) -> bytes:
        pass

    @abstractmethod
    def serialize(
        self,
        lookup: List[bytes]
    ) -> bytes:
        pass

    @abstractmethod
    def toJSON(
        self
    ) -> Dict[str, Any]:
        pass

    def toElement(
        self
    ) -> Any:
        return self

#SignedElement helper class.
class SignedElement(Element):
    signature: bytes

    @staticmethod
    def fromElement(
        elem: Element
    ) -> Any:
        return elem

    @abstractmethod
    def signedSerialize(
        self
    ) -> bytes:
        pass

    @abstractmethod
    def toSignedJSON(
        self
    ) -> Dict[str, Any]:
        pass
