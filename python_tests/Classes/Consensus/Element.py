#Types.
from typing import Dict, Any

#Element root class.
class Element:
    holder: bytes
    nonce: int

    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Element toJSON called.")
