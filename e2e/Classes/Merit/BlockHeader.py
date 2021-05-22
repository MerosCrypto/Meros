from typing import Dict, List, Union, Any
from hashlib import blake2b

from e2e.Libs.BLS import PrivateKey, Signature
from e2e.Libs.RandomX import RandomX
from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

def merkle(
  hashes: List[bytes]
) -> bytes:
  if not hashes:
    return bytes(32)

  while len(hashes) > 1:
    if len(hashes) % 2 != 0:
      hashes.append(hashes[-1])
    for h in range(len(hashes) // 2):
      hashes[h] = blake2b(
        hashes[h * 2] + hashes[(h * 2) + 1],
        digest_size=32
      ).digest()
    hashes = hashes[0 : len(hashes) // 2]

  return hashes[0]

#pylint: disable=too-many-instance-attributes
class BlockHeader:
  #Defined here to avoid warnings.
  hash: bytes

  @staticmethod
  def createContents(
    packetsArg: List[VerificationPacket] = [],
    elements: List[Element] = []
  ) -> bytes:
    packets: List[VerificationPacket] = sorted(
      list(packetsArg),
      key=lambda packet: packet.hash[::-1]
    )

    hashes: List[bytes] = []
    for packet in packets:
      hashes.append(blake2b(packet.prefix + packet.serialize(), digest_size=32).digest())
    packetsContents: bytes = merkle(hashes)

    hashes = []
    for element in elements:
      hashes.append(blake2b(element.prefix + element.serialize(), digest_size=32).digest())
    elementsContents: bytes = merkle(hashes)

    if (packetsContents == bytes(32)) and (elementsContents == bytes(32)):
      return bytes(32)
    return blake2b(packetsContents + elementsContents, digest_size=32).digest()

  @staticmethod
  def createSketchCheck(
    salt: bytes = bytes(4),
    packets: List[VerificationPacket] = []
  ) -> bytes:
    sketchHashes: List[int] = []
    for packet in packets:
      sketchHashes.append(Sketch.hash(salt, packet))
    sketchHashes.sort()

    #Hash each sketch hash to leaf length.
    leaves: List[bytes] = []
    for sketchHash in sketchHashes:
      leaves.append(blake2b(sketchHash.to_bytes(8, byteorder="little"), digest_size=32).digest())

    return merkle(leaves)

  def serializeHash(
    self
  ) -> bytes:
    return (
      self.version.to_bytes(4, "little") +
      self.last +
      self.contents +
      self.packetsQuantity.to_bytes(4, "little") +
      self.sketchSalt +
      self.sketchCheck +
      (1 if self.newMiner else 0).to_bytes(1, "little") +
      (self.minerKey if self.newMiner else self.minerNick.to_bytes(2, "little")) +
      self.time.to_bytes(4, "little") +
      self.proof.to_bytes(4, "little")
    )

  def rehash(
    self
  ) -> None:
    self.hash = RandomX(RandomX(self.serializeHash()) + self.signature)

  def __init__(
    self,
    version: int,
    last: bytes,
    contents: bytes,
    packetsQuantity: int,
    sketchSalt: bytes,
    sketchCheck: bytes,
    miner: Union[int, bytes],
    time: int,
    proof: int = 0,
    signature: bytes = Signature().serialize()
  ) -> None:
    self.version: int = version
    self.last: bytes = last
    self.contents: bytes = contents

    self.packetsQuantity: int = packetsQuantity
    self.sketchSalt: bytes = sketchSalt
    self.sketchCheck: bytes = sketchCheck

    self.newMiner: bool = isinstance(miner, bytes)
    if isinstance(miner, bytes):
      self.minerKey: bytes = miner
    else:
      self.minerNick: int = miner
    self.time: int = time
    self.proof: int = proof
    self.signature: bytes = signature

    self.rehash()

  def mine(
    self,
    privKey: PrivateKey,
    difficultyArg: int
  ) -> None:
    difficulty: int = difficultyArg
    if self.newMiner:
      difficulty = difficulty * 11 // 10

    self.proof = -1
    while (
      (self.proof == -1) or
      ((int.from_bytes(self.hash, "little") * difficulty) > int.from_bytes(bytes.fromhex("FF" * 32), "little"))
    ):
      self.proof += 1
      self.hash = RandomX(self.serializeHash())
      self.signature = privKey.sign(self.hash).serialize()
      self.hash = RandomX(self.hash + self.signature)

  def serialize(
    self
  ) -> bytes:
    return self.serializeHash() + self.signature

  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "version": self.version,
      "last": self.last.hex().upper(),
      "contents": self.contents.hex().upper(),
      "packets": self.packetsQuantity,
      "sketchSalt": self.sketchSalt.hex().upper(),
      "sketchCheck": self.sketchCheck.hex().upper(),
      "miner": self.minerKey.hex().upper() if self.newMiner else self.minerNick,
      "time": self.time,
      "proof": self.proof,
      "signature": self.signature.hex().upper()
    }

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> "BlockHeader":
    return BlockHeader(
      json["version"],
      bytes.fromhex(json["last"]),
      bytes.fromhex(json["contents"]),
      json["packets"],
      bytes.fromhex(json["sketchSalt"]),
      bytes.fromhex(json["sketchCheck"]),
      bytes.fromhex(json["miner"]) if isinstance(json["miner"], str) else json["miner"],
      json["time"],
      json["proof"],
      bytes.fromhex(json["signature"])
    )
