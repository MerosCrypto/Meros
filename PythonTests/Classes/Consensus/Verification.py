#Types.
from typing import Dict, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, Signature

#Element class.
from PythonTests.Classes.Consensus.Element import Element, SignedElement

#Verification Prefix.
VERIFICATION_PREFIX: bytes = b'\0'

#Verification class.
class Verification(
  Element
):
  #Constructor.
  def __init__(
    self,
    txHash: bytes,
    holder: int
  ) -> None:
    self.prefix: bytes = VERIFICATION_PREFIX

    self.hash: bytes = txHash
    self.holder: int = holder

  #Serialize for signing.
  def signatureSerialize(
    self
  ) -> bytes:
    return self.prefix + self.hash

  #Serialize.
  def serialize(
    self
  ) -> bytes:
    return self.holder.to_bytes(2, "big") + self.hash

  #Verification -> JSON.
  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "Verification",

      "hash": self.hash.hex().upper(),
      "holder": self.holder
    }

  #JSON -> Verification.
  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return Verification(bytes.fromhex(json["hash"]), json["holder"])

class SignedVerification(
  SignedElement,
  Verification
):
  #Constructor.
  def __init__(
    self,
    txHash: bytes,
    holder: int = 0,
    signature: Signature = Signature()
  ) -> None:
    Verification.__init__(self, txHash, holder)
    self.signature: Signature = signature

  #Sign.
  def sign(
    self,
    holder: int,
    privKey: PrivateKey
  ) -> None:
    self.holder = holder
    self.signature = privKey.sign(self.signatureSerialize())

  #Serialize.
  #pylint: disable=unused-argument
  def signedSerialize(
    self
  ) -> bytes:
    return Verification.serialize(self) + self.signature.serialize()

  #SignedVerification -> JSON.
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

  #JSON -> SignedVerification.
  @staticmethod
  def fromSignedJSON(
    json: Dict[str, Any]
  ) -> Any:
    return SignedVerification(
      bytes.fromhex(json["hash"]),
      json["holder"],
      Signature(bytes.fromhex(json["signature"]))
    )
