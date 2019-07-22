#Types.
from typing import Dict, Any

#Element root class.
class Element:
    def toJSON(
        self
    ) -> Dict[str, Any]:
        raise Exception("Base Element toJSON called.")
