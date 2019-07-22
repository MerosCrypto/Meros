#Types.
from typing import Dict, List, Any

#Element classes.
from python_tests.Classes.Consensus.Element import Element
from python_tests.Classes.Consensus.Verification import Verification

#Consensus class.
class Consensus:
    #Constructor.
    def __init__(
        self
    ) -> None:
        self.holders: Dict[bytes, List[Element]] = {}

    #Add an Element.
    def add(
        self,
        elem: Element
    ) -> None:
        if not elem.holder in self.holders:
            self.holders[elem.holder] = []
        self.holders[elem.holder].append(elem)

    #Consensus -> JSON.
    def toJSON(
        self
    ) -> Dict[str, List[Dict[str, Any]]]:
        result: Dict[str, List[Dict[str, Any]]] = {}
        for holder in self.holders:
            result[holder.hex().upper()] = []
            for elem in self.holders[holder]:
                result[holder.hex().upper()].append(elem.toJSON())
        return result

    #JSON -> Consensus.
    @staticmethod
    def fromJSON(
        json: Dict[str, List[Dict[str, Any]]]
    ) -> Any:
        result = Consensus()
        for mh in json:
            for elem in json[mh]:
                if elem["descendant"] == "verification":
                    result.add(Verification.fromJSON(elem))
        return result
