#pylint: disable=no-self-use

#Types.
from typing import Dict, Any

#Transaction root class.
class Transaction:
    txHash: bytes
    verified: bool

    def serialize(
        self
    ) -> bytes:
        raise Exception("Base Transaction serialize called.")

    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Transaction toJSON called.")

    def toVector(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Transaction toVector called.")
