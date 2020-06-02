#Types.
from typing import Dict, List, Optional, Any

#BLS lib.
from PythonTests.Libs.BLS import Signature

#Element classes.
from PythonTests.Classes.Consensus.Element import Element, SignedElement

#SignedVerification class.
from PythonTests.Classes.Consensus.Verification import SignedVerification

#VerificationPacket Prefix.
VERIFICATION_PACKET_PREFIX: bytes = b'\1'

#VerificationPacket class.
class VerificationPacket(
  Element
):
  #Constructor.
  def __init__(
    self,
    txHash: bytes,
    holders: List[int]
  ) -> None:
    self.prefix: bytes = VERIFICATION_PACKET_PREFIX

    self.hash: bytes = txHash
    self.holders: List[int] = holders

  #'Signature' serialize. Used by MeritRemovals.
  def signatureSerialize(
    self
  ) -> bytes:
    raise Exception("VerificationPacket's signatureSerialize was called.")

  #Serialize.
  def serialize(
    self
  ) -> bytes:
    result: bytes = len(self.holders).to_bytes(2, "big")
    for holder in sorted(self.holders):
      result += holder.to_bytes(2, "big")
    result += self.hash
    return result

  #VerificationPacket -> JSON.
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

class MeritRemovalVerificationPacket(
  VerificationPacket
):
  #Constructor.
  #pylint: disable=super-init-not-called
  def __init__(
    self,
    txHash: bytes,
    holderKeys: List[bytes]
  ) -> None:
    self.prefix: bytes = VERIFICATION_PACKET_PREFIX

    self.hash: bytes = txHash
    self.holderKeys: List[bytes] = holderKeys

  #'Signature' serialize. Used by MeritRemovals.
  def signatureSerialize(
    self
  ) -> bytes:
    result: bytes = self.prefix + len(self.holderKeys).to_bytes(2, "big")
    for holder in self.holderKeys:
      result += holder
    result += self.hash
    return result

  #MeritRemovalVerificationPacket -> JSON.
  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = {
      "descendant": "VerificationPacket",

      "hash": self.hash.hex().upper(),
      "holders": []
    }

    for holder in self.holderKeys:
      result["holders"].append(holder.hex().upper())

    return result

  #JSON -> VerificationPacket.
  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    holders: List[bytes] = []
    for holder in json["holders"]:
      holders.append(bytes.fromhex(holder))
    return MeritRemovalVerificationPacket(bytes.fromhex(json["hash"]), holders)

class SignedVerificationPacket(
  SignedElement,
  VerificationPacket
):
  #Constructor.
  def __init__(
    self,
    txHash: bytes,
    holders: List[int] = [],
    signature: Signature = Signature()
  ) -> None:
    VerificationPacket.__init__(self, txHash, holders)
    self.signature: Signature = signature

  #Add a SignedVerification.
  def add(
    self,
    verif: SignedVerification
  ) -> None:
    self.holders.append(verif.holder)

    if self.signature.isInf():
      self.signature = verif.signature
    else:
      self.signature = Signature.aggregate([self.signature, verif.signature])

  #Serialize.
  def signedSerialize(
    self
  ) -> bytes:
    return VerificationPacket.serialize(self) + self.signature.serialize()

  #SignedVerificationPacket -> JSON.
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

  #JSON -> SignedVerificationPacket.
  @staticmethod
  def fromSignedJSON(
    json: Dict[str, Any]
  ) -> Any:
    return SignedVerificationPacket(
      bytes.fromhex(json["hash"]),
      json["holders"],
      Signature(bytes.fromhex(json["signature"]))
    )

class SignedMeritRemovalVerificationPacket(
  SignedVerificationPacket
):
  #Constructor.
  #pylint: disable=super-init-not-called
  def __init__(
    self,
    packet: SignedVerificationPacket,
    holdersOrLookup: List[bytes],
    signature: Optional[Signature]
  ) -> None:
    self.prefix: bytes = VERIFICATION_PACKET_PREFIX

    self.hash: bytes = packet.hash

    self.holderKeys: List[bytes]
    self.signature: Signature

    if signature is None:
      for holder in packet.holders:
        self.holderKeys.append(holdersOrLookup[holder])
      self.signature = packet.signature
    else:
      self.holderKeys = holdersOrLookup
      self.signature = signature

  #'Signature' serialize. Used by MeritRemovals.
  def signatureSerialize(
    self
  ) -> bytes:
    result: bytes = self.prefix + len(self.holderKeys).to_bytes(2, "big")
    for holder in self.holderKeys:
      result += holder
    result += self.hash
    return result

  def signedSerialize(
    self
  ) -> bytes:
    raise Exception("SignedMeritRemovalVerificationPacket's signedSerialize was called.")

  #SignedMeritRemovalVerificationPacket -> JSON.
  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = {
      "descendant": "VerificationPacket",

      "hash": self.hash.hex().upper(),
      "holders": []
    }

    for holder in self.holderKeys:
      result["holders"].append(holder.hex().upper())

    return result

  def toSignedJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = self.toJSON()
    result["signed"] = True
    result["signature"] = self.signature.serialize().hex().upper()
    return result

  #JSON -> SignedMeritRemovalVerificationPacket.
  @staticmethod
  def fromSignedJSON(
    json: Dict[str, Any]
  ) -> Any:
    holders: List[bytes] = []
    for holder in json["holders"]:
      holders.append(bytes.fromhex(holder))

    return SignedMeritRemovalVerificationPacket(
      SignedVerificationPacket(bytes.fromhex(json["hash"])),
      holders,
      Signature(bytes.fromhex(json["signature"]))
    )
