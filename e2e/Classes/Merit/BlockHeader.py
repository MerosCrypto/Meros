#Types.
from typing import Dict, List, Union, Any

#BLS lib.
from e2e.Libs.BLS import Signature

#Element classes.
from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

#Sketch class.
from e2e.Libs.Minisketch import Sketch

#RandomX lib.
from e2e.Libs.RandomX import RandomX

#Blake2b standard function.
from hashlib import blake2b

#Merkle constructor.
def merkle(
  hashes: List[bytes]
) -> bytes:
  #Support empty Merkles.
  if not hashes:
    return bytes(32)

  #Pair down until there's one hash left.
  while len(hashes) > 1:
    if len(hashes) % 2 != 0:
      hashes.append(hashes[-1])
    for h in range(len(hashes) // 2):
      hashes[h] = blake2b(
        hashes[h * 2] + hashes[(h * 2) + 1],
        digest_size=32
      ).digest()
    hashes = hashes[0 : len(hashes) // 2]

  #Return the Merkle hash.
  return hashes[0]

#BlockHeader class.
#pylint: disable=too-many-instance-attributes
class BlockHeader:
  #Create a contents Merkle.
  @staticmethod
  def createContents(
    packetsArg: List[VerificationPacket] = [],
    elements: List[Element] = []
  ) -> bytes:
    #Sort the VerificationPackets.
    packets: List[VerificationPacket] = sorted(
      list(packetsArg),
      key=lambda packet: packet.hash
    )

    #Hash each packet.
    hashes: List[bytes] = []
    for packet in packets:
      hashes.append(blake2b(packet.prefix + packet.serialize(), digest_size=32).digest())
    packetsContents: bytes = merkle(hashes)

    #Hash each Element.
    hashes = []
    for element in elements:
      hashes.append(blake2b(element.prefix + element.serialize(), digest_size=32).digest())
    elementsContents: bytes = merkle(hashes)

    #Return the contents hash.
    if (packetsContents == bytes(32)) and (elementsContents == bytes(32)):
      return bytes(32)
    return blake2b(packetsContents + elementsContents, digest_size=32).digest()

  #Create a sketchCheck Merkle.
  @staticmethod
  def createSketchCheck(
    salt: bytes = bytes(4),
    packets: List[VerificationPacket] = []
  ) -> bytes:
    #Create sketch hashes for every packet.
    sketchHashes: List[int] = []
    for packet in packets:
      sketchHashes.append(Sketch.hash(salt, packet))

    #Sort the Sketch Hashes.
    sketchHashes.sort()

    #Hash each sketch hash to leaf length.
    leaves: List[bytes] = []
    for sketchHash in sketchHashes:
      leaves.append(blake2b(sketchHash.to_bytes(8, byteorder="big"), digest_size=32).digest())

    #Return the Merkle hash.
    return merkle(leaves)

  #Serialize to be hashed.
  def serializeHash(
    self
  ) -> bytes:
    return (
      self.version.to_bytes(4, "big") +
      self.last +
      self.contents +
      self.significant.to_bytes(2, "big") +
      self.sketchSalt +
      self.sketchCheck +
      (1 if self.newMiner else 0).to_bytes(1, "big") +
      (self.minerKey if self.newMiner else self.minerNick.to_bytes(2, "big")) +
      self.time.to_bytes(4, "big") +
      self.proof.to_bytes(4, "big")
    )

  #Hash.
  def rehash(
    self
  ) -> None:
    self.hash: bytes = RandomX(RandomX(self.serializeHash()) + self.signature)

  #Constructor.
  def __init__(
    self,
    version: int,
    last: bytes,
    contents: bytes,
    significant: int,
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

    self.significant: int = significant
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

  #Serialize.
  def serialize(
    self
  ) -> bytes:
    return self.serializeHash() + self.signature

  #BlockHeader -> JSON.
  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "version": self.version,
      "last": self.last.hex().upper(),
      "contents": self.contents.hex().upper(),
      "significant": self.significant,
      "sketchSalt": self.sketchSalt.hex().upper(),
      "sketchCheck": self.sketchCheck.hex().upper(),
      "miner": self.minerKey.hex().upper() if self.newMiner else self.minerNick,
      "time": self.time,
      "proof": self.proof,
      "signature": self.signature.hex().upper()
    }

  #JSON -> BlockHeader.
  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return BlockHeader(
      json["version"],
      bytes.fromhex(json["last"]),
      bytes.fromhex(json["contents"]),
      json["significant"],
      bytes.fromhex(json["sketchSalt"]),
      bytes.fromhex(json["sketchCheck"]),
      bytes.fromhex(json["miner"]) if isinstance(json["miner"], str) else json["miner"],
      json["time"],
      json["proof"],
      bytes.fromhex(json["signature"])
    )
