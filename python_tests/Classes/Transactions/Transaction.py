#Types.
from typing import Dict, Any

#Transaction root class.
class Transaction:
    hash: bytes
    verified: bool

    def serialize(
        self
    ) -> bytes:
        raise Exception("Base Transaction serialize called.")

    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Transaction toJSON called.")
