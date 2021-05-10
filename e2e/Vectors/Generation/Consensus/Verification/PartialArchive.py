from typing import List
from hashlib import blake2b
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

blockchain: Blockchain = Blockchain()

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [key.toPublicKey() for key in blsPrivKeys]

#Create two holders.
for h in range(2):
  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      0,
      bytes(4),
      bytes(32),
      blsPubKeys[h].serialize(),
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(blsPrivKeys[h], blockchain.difficulty())
  blockchain.add(block)

#Create a Data and two Signed Verifications.
data: Data = Data(bytes(32), edPubKey)
data.sign(edPrivKey)
data.beat(dataFilter)

svs: List[SignedVerification] = [
  SignedVerification(data.hash),
  SignedVerification(data.hash)
]
for h in range(2):
  svs[h].sign(h, blsPrivKeys[h])

#Create a packet with the first Verification.
packet: List[VerificationPacket] = [VerificationPacket(data.hash, [0])]
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents(packet),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packet),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packet, [], svs[0].signature)
)
block.mine(blsPrivKeys[0], blockchain.difficulty())
blockchain.add(block)

with open("e2e/Vectors/Consensus/Verification/PartialArchive.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": blockchain.toJSON(),
    "data": data.toJSON(),
    "verifs": [v.toSignedJSON() for v in svs]
  }))
