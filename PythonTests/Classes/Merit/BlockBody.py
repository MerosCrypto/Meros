#Types.
from typing import Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import Signature

#Minisketch lib.
from PythonTests.Libs.Minisketch import Sketch

#Element classes.
from PythonTests.Classes.Consensus.Element import Element
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket
from PythonTests.Classes.Consensus.SendDifficulty import SendDifficulty
from PythonTests.Classes.Consensus.DataDifficulty import DataDifficulty
from PythonTests.Classes.Consensus.MeritRemoval import MeritRemoval

#Merkle function.
from PythonTests.Classes.Merit.BlockHeader import merkle

#Blake2b standard function.
from hashlib import blake2b

#BlockBody class.
class BlockBody:
    #Constructor.
    def __init__(
        self,
        packets: List[VerificationPacket] = [],
        elements: List[Element] = [],
        aggregate: Signature = Signature()
    ) -> None:
        self.packets: List[VerificationPacket] = list(packets)
        self.packets.sort(key=lambda packet: packet.hash, reverse=True)

        packetsMerkle: List[bytes] = []
        for packet in packets:
            packetsMerkle.append(blake2b(packet.prefix + packet.serialize(), digest_size=32).digest())
        self.packetsContents: bytes = merkle(packetsMerkle)

        self.elements: List[Element] = list(elements)
        self.aggregate: Signature = aggregate

    #Serialize.
    def serialize(
        self,
        lookup: List[bytes],
        sketchSalt: bytes,
        capacityArg: int = -1
    ) -> bytes:
        capacity: int = capacityArg
        if capacity == -1:
            capacity = len(self.packets) // 5 + 1 if len(self.packets) != 0 else 0

        sketch: Sketch = Sketch(capacity)
        for packet in self.packets:
            sketch.add(sketchSalt, packet)

        result: bytes = (
            self.packetsContents +
            capacity.to_bytes(4, "big") +
            sketch.serialize() +
            len(self.elements).to_bytes(4, "big")
        )

        for elem in self.elements:
            result += elem.prefix + elem.serialize(lookup)

        result += self.aggregate.serialize()
        return result

    #BlockBody -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "transactions": [],
            "elements": [],
            "aggregate": self.aggregate.serialize().hex().upper()
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
        keys: Dict[bytes, int],
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
            if element["descendant"] == "SendDifficulty":
                elements.append(SendDifficulty.fromJSON(element))
            elif element["descendant"] == "DataDifficulty":
                elements.append(DataDifficulty.fromJSON(element))
            elif element["descendant"] == "MeritRemoval":
                elements.append(MeritRemoval.fromJSON(keys, element))

        return BlockBody(packets, elements, Signature(bytes.fromhex(json["aggregate"])))
