from typing import Dict, Any

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Consensus.Element import Element, SignedElement

DATA_DIFFICULTY_PREFIX: bytes = b'\3'

class DataDifficulty(
  Element
):
  def __init__(
    self,
    difficulty: int,
    nonce: int,
    holder: int
  ) -> None:
    self.prefix: bytes = DATA_DIFFICULTY_PREFIX
    self.difficulty: int = difficulty
    self.nonce: int = nonce
    self.holder: int = holder

  def signatureSerialize(
    self
  ) -> bytes:
    return DATA_DIFFICULTY_PREFIX + self.nonce.to_bytes(4, "big") + self.difficulty.to_bytes(4, "big")

  def serialize(
    self
  ) -> bytes:
    return self.holder.to_bytes(2, "big") + self.nonce.to_bytes(4, "big") + self.difficulty.to_bytes(4, "big")

  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "DataDifficulty",
      "difficulty": self.difficulty,
      "nonce": self.nonce,
      "holder": self.holder
    }

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return DataDifficulty(json["difficulty"], json["nonce"], json["holder"])

class SignedDataDifficulty(
  SignedElement,
  DataDifficulty
):
  def __init__(
    self,
    difficulty: int,
    nonce: int = 0,
    holder: int = 0,
    signature: Signature = Signature()
  ) -> None:
    DataDifficulty.__init__(self, difficulty, nonce, holder)
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
    return DataDifficulty.serialize(self) + self.signature.serialize()

  def toSignedJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "DataDifficulty",
      "holder": self.holder,
      "nonce": self.nonce,
      "difficulty": self.difficulty,
      "signed": True,
      "signature": self.signature.serialize().hex().upper()
    }

  @staticmethod
  def fromSignedJSON(
    json: Dict[str, Any]
  ) -> Any:
    return SignedDataDifficulty(
      json["difficulty"],
      json["nonce"],
      json["holder"],
      Signature(bytes.fromhex(json["signature"]))
    )
