#pylint: disable=no-self-use

#Types.
from typing import Dict, Any

#BLS lib.
from PythonTests.Libs.BLS import Signature

#Abstract class standard lib.
from abc import ABC, abstractmethod

#Element class
class Element(
    ABC
):
    prefix: bytes
    holder: int

    @abstractmethod
    def signatureSerialize(
        self
    ) -> bytes:
        pass

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

#SignedElement class.
class SignedElement(
    ABC
):
    signature: Signature

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
