from typing import Dict, List, Any

from e2e.Libs.BLS import Signature

from e2e.Classes.Consensus.Element import Element, SignedElement
from e2e.Classes.Consensus.Verification import SignedVerification

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
  ) -> Any:
    return VerificationPacket(bytes.fromhex(json["hash"]), json["holders"])

class SignedVerificationPacket(
  SignedElement,
  VerificationPacket
):
  def __init__(
    self,
    txHash: bytes,
    holders: List[int] = [],
    signature: Signature = Signature()
  ) -> None:
    VerificationPacket.__init__(self, txHash, holders)
    self.signature: Signature = signature

  def add(
    self,
    verif: SignedVerification
  ) -> None:
    self.holders.append(verif.holder)
    if self.signature.isInf():
      self.signature = verif.signature
    else:
      self.signature = Signature.aggregate([self.signature, verif.signature])

  def signedSerialize(
    self
  ) -> bytes:
    return VerificationPacket.serialize(self) + self.signature.serialize()

  def toSignedJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "VerificationPacket",
      "holders": self.holders,
      "hash": self.hash.hex().upper(),
      "signed": True,
      "signature": self.signature.serialize().hex().upper()
    }

  @staticmethod
  def fromSignedJSON(
    json: Dict[str, Any]
  ) -> Any:
    return SignedVerificationPacket(
      bytes.fromhex(json["hash"]),
      json["holders"],
      Signature(bytes.fromhex(json["signature"]))
    )
