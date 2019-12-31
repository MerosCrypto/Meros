#Types.
from typing import Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import Signature

#Minisketch lib.
from PythonTests.Libs.Minisketch import Sketch

#Element classes.
from PythonTests.Classes.Consensus.Element import Element
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket
from PythonTests.Classes.Consensus.DataDifficulty import DataDifficulty

#BlockBody class.
class BlockBody:
    #Constructor.
    def __init__(
        self,
        packets: List[VerificationPacket] = [],
        elements: List[Element] = [],
        aggregate: bytes = Signature().serialize()
    ) -> None:
        self.packets: List[VerificationPacket] = list(packets)
        self.packets.sort(key=lambda packet: packet.hash, reverse=True)

        self.elements: List[Element] = list(elements)
        self.aggregate: bytes = aggregate

    #Serialize.
    def serialize(
        self,
        sketchSalt: bytes
    ) -> bytes:
        capacity: int = len(self.packets) // 5 + 1 if len(self.packets) != 0 else 0
        sketch: Sketch = Sketch(capacity)
        for packet in self.packets:
            sketch.add(sketchSalt, packet)

        result: bytes = (
            capacity.to_bytes(4, "big") +
            sketch.serialize() +
            len(self.elements).to_bytes(4, "big")
        )

        for elem in self.elements:
            result += elem.prefix + elem.serialize()

        result += self.aggregate
        return result

    #BlockBody -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "transactions": [],
            "elements": [],
            "aggregate": self.aggregate.hex().upper()
        }

        for packet in self.packets:
            result["transactions"].append({
                "hash": packet.hash.hex().upper(),
                "holders": sorted(packet.holders)
            })

        for element in self.elements:
            result["elements"].append(element.toJSON())

        return result

    #JSON -> Blockbody.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        packets: List[VerificationPacket] = []
        elements: List[Element] = []

        for packet in json["transactions"]:
            packets.append(
                VerificationPacket(
                    bytes.fromhex(packet["hash"]),
                    packet["holders"]
                )
            )

        for element in json["elements"]:
            if element["descendant"] == "DataDifficulty":
                elements.append(DataDifficulty.fromJSON(element))

        return BlockBody(packets, elements, bytes.fromhex(json["aggregate"]))
