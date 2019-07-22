#Types.
from typing import Dict, Any

#Transaction root class.
class Transaction:
    hash: bytes
    
    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Transaction toJSON called.")
