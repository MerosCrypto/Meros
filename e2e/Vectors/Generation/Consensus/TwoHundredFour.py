from typing import List
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket, MeritRemovalVerificationPacket
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

blockchain: Blockchain = Blockchain()
blocks: List[Block] = []

#Generate a Block granting the holder Merit.
blank: Block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKey.serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
blank.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(blank)

#Generate a Block which has a VP with no holders.
vp: VerificationPacket = VerificationPacket(b'z' * 32, [])
blocks.append(
  Block(
    BlockHeader(
      0,
      blockchain.last(),
      BlockHeader.createContents([vp]),
      1,
      bytes(4),
      BlockHeader.createSketchCheck(bytes(4), [vp]),
      0,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([vp], [], blsPrivKey.sign(b''))
  )
)
blocks[-1].mine(blsPrivKey, blockchain.difficulty())

#Generate a Block which has a MR VP with no holders.
mr: MeritRemoval = MeritRemoval(
  MeritRemovalVerificationPacket(b'z' * 32, []),
  MeritRemovalVerificationPacket(b'z' * 32, []),
  False,
  0
)
blocks.append(
  Block(
    BlockHeader(
      0,
      blockchain.last(),
      BlockHeader.createContents([], [mr]),
      1,
      bytes(4),
      bytes(32),
      0,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [mr], blsPrivKey.sign(b''))
  )
)
blocks[-1].mine(blsPrivKey, blockchain.difficulty())

with open("e2e/Vectors/Consensus/TwoHundredFour.json", "w") as vectors:
  vectors.write(json.dumps({
    "blank": blank.toJSON(),
    "blocks": [block.toJSON() for block in blocks]
  }))
