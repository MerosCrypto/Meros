#pylint: disable=no-self-use

#Types.
from typing import Dict, Any

#Abstract class standard lib.
from abc import ABC, abstractmethod

#Transaction root class.
class Transaction(ABC):
    txHash: bytes
    verified: bool

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

    @abstractmethod
    def toVector(
        self
    ) -> Dict[str, Any]:
        pass
