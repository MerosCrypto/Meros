#Types.
from typing import Dict, Any

#Transaction root class.
class Transaction:
    hash: bytes
    verified: bool

    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Transaction toJSON called.")
