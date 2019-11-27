#pylint: disable=no-self-use

#Types.
from typing import Dict, Any

#Abstract class standard lib.
from abc import ABC, abstractmethod

#Element root class.
class Element(ABC):
    prefix: bytes

    @abstractmethod
    def serialize(
        self
    ) -> bytes:
        pass

    @abstractmethod
    def toJSON(
        self
    ) -> Dict[str, Any]:
        pass

#SignedElement helper class.
class SignedElement(Element):
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
