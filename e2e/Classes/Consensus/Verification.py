from typing import Dict, Any

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Consensus.Element import Element, SignedElement

VERIFICATION_PREFIX: bytes = b'\0'

class Verification(
  Element
):
  def __init__(
    self,
    txHash: bytes,
    holder: int
  ) -> None:
    self.prefix: bytes = VERIFICATION_PREFIX
    self.hash: bytes = txHash
    self.holder: int = holder

  def signatureSerialize(
    self
  ) -> bytes:
    return self.prefix + self.hash

  def serialize(
    self
  ) -> bytes:
    return self.holder.to_bytes(2, "big") + self.hash

  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "Verification",
      "hash": self.hash.hex().upper(),
      "holder": self.holder
    }

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return Verification(bytes.fromhex(json["hash"]), json["holder"])

class SignedVerification(
  SignedElement,
  Verification
):
  def __init__(
    self,
    txHash: bytes,
    holder: int = 0,
    signature: Signature = Signature()
  ) -> None:
    Verification.__init__(self, txHash, holder)
    self.signature: Signature = signature

  def sign(
    self,
    holder: int,
    privKey: PrivateKey
  ) -> None:
    self.holder = holder
    self.signature = privKey.sign(self.signatureSerialize())

  def signedSerialize(
    self
  ) -> bytes:
    return Verification.serialize(self) + self.signature.serialize()

  def toSignedJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "Verification",
      "holder": self.holder,
      "hash": self.hash.hex().upper(),
      "signed": True,
      "signature": self.signature.serialize().hex().upper()
    }

  @staticmethod
  def fromSignedJSON(
    json: Dict[str, Any]
  ) -> Any:
    return SignedVerification(
      bytes.fromhex(json["hash"]),
      json["holder"],
      Signature(bytes.fromhex(json["signature"]))
    )
