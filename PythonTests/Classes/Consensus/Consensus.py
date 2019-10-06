#Types.
from typing import Dict, List, Any

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Consensus class.
class Consensus:
    #Constructor.
    def __init__(
        self,
        sendDiff: bytes,
        dataDiff: bytes
    ) -> None:
        self.sendFilter = SpamFilter(sendDiff)
        self.dataFilter = SpamFilter(dataDiff)

    #Consensus -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Dict[str, Any]]:
        result: Dict[str, Dict[str, Any]] = {}
        return result

    #JSON -> Consensus.
    @staticmethod
    def fromJSON(
        sendDiff: bytes,
        dataDiff: bytes,
        json: Dict[str, List[Dict[str, Any]]]
    ) -> Any:
        result = Consensus(sendDiff, dataDiff)
        return result
