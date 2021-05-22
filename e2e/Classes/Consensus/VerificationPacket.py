from typing import Dict, List, Any

from e2e.Classes.Consensus.Element import Element

VERIFICATION_PACKET_PREFIX: bytes = b'\1'

class VerificationPacket(
  Element
):
  def __init__(
    self,
    txHash: bytes,
    holders: List[int]
  ) -> None:
    self.prefix: bytes = VERIFICATION_PACKET_PREFIX
    self.hash: bytes = txHash
    self.holders: List[int] = holders

  def signatureSerialize(
    self
  ) -> bytes:
    raise Exception("VerificationPacket's signatureSerialize was called.")

  def serialize(
    self
  ) -> bytes:
    result: bytes = len(self.holders).to_bytes(2, "little")
    for holder in sorted(self.holders):
      result += holder.to_bytes(2, "little")
    result += self.hash
    return result

  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "VerificationPacket",
      "hash": self.hash.hex().upper(),
      "holders": self.holders
    }

  #JSON -> VerificationPacket.
  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> "VerificationPacket":
    return VerificationPacket(bytes.fromhex(json["hash"]), json["holders"])
