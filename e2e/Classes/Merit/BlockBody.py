from typing import Dict, List, Any
from hashlib import blake2b

from e2e.Libs.BLS import Signature
from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Classes.Merit.BlockHeader import merkle

class BlockBody:
  def __init__(
    self,
    packets: List[VerificationPacket] = [],
    elements: List[Element] = [],
    aggregate: Signature = Signature()
  ) -> None:
    self.packets: List[VerificationPacket] = sorted(
      list(packets),
      key=lambda packet: packet.hash[::-1]
    )

    packetsMerkle: List[bytes] = []
    for packet in self.packets:
      packetsMerkle.append(blake2b(packet.prefix + packet.serialize(), digest_size=32).digest())
    self.packetsContents: bytes = merkle(packetsMerkle)

    self.elements: List[Element] = list(elements)
    self.aggregate: Signature = aggregate

  def serialize(
    self,
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
      capacity.to_bytes(4, "little") +
      sketch.serialize() +
      len(self.elements).to_bytes(4, "little")
    )

    for elem in self.elements:
      result += elem.prefix + elem.serialize()

    result += self.aggregate.serialize()
    return result

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

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    packets: List[VerificationPacket] = []
    elements: List[Element] = []

    for packet in json["transactions"]:
      packets.append(
        VerificationPacket(bytes.fromhex(packet["hash"]), packet["holders"])
      )

    for element in json["elements"]:
      if element["descendant"] == "SendDifficulty":
        elements.append(SendDifficulty.fromJSON(element))
      elif element["descendant"] == "DataDifficulty":
        elements.append(DataDifficulty.fromJSON(element))
      elif element["descendant"] == "MeritRemoval":
        elements.append(MeritRemoval.fromJSON(element))

    return BlockBody(packets, elements, Signature(bytes.fromhex(json["aggregate"])))
