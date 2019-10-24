#Types.
from typing import Dict, List, Any

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Minisketch lib.
from PythonTests.Classes.Merit.Minisketch import Sketch

#BlockBody class.
class BlockBody:
    #Constructor.
    def __init__(
        self,
        significant: int = 0,
        sketchSalt: bytes = bytes(4),
        packets: List[VerificationPacket] = [],
        elements: List[None] = [],
        aggregate: bytes = bytes(96)
    ) -> None:
        self.significant: int = significant
        self.sketchSalt: bytes = sketchSalt
        self.packets: List[VerificationPacket] = list(packets)
        self.elements: List[None] = list(elements)
        self.aggregate: bytes = aggregate

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        capacity: int = len(self.packets) // 5 + 1 if len(self.packets) != 0 else 0
        sketch: Sketch = Sketch(capacity)
        for packet in self.packets:
            sketch.add(self.sketchSalt, packet)

        result: bytes = (
            self.significant.to_bytes(4, "big") +
            self.sketchSalt +
            capacity.to_bytes(4, "big") +
            sketch.serialize() +
            len(self.elements).to_bytes(4, "big")
        )

        for _ in self.elements:
            pass

        result += self.aggregate
        return result

    #BlockBody -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "transactions": [],
            "significant": self.significant,
            "sketchSalt": self.sketchSalt.hex().upper(),
            "elements": [],
            "aggregate": self.aggregate.hex().upper()
        }

        for packet in self.packets:
            result["transactions"].append({
                "hash": packet.hash.hex().upper(),
                "holders": packet.holders
            })

        return result

    #JSON -> Blockbody.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        packets: List[VerificationPacket] = []
        elements: List[None] = []

        for packet in json["transactions"]:
            packets.append(
                VerificationPacket(
                    bytes.fromhex(packet["hash"]),
                    packet["holders"]
                )
            )

        for _ in json["elements"]:
            pass

        return BlockBody(
            json["significant"],
            bytes.fromhex(json["sketchSalt"]),
            packets,
            elements,
            bytes.fromhex(json["aggregate"])
        )
