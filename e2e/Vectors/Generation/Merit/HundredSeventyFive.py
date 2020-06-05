from typing import List, IO, Any

from hashlib import blake2b
import json

import ed25519

from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

blockchain: Blockchain = Blockchain()
dataFilter: SpamFilter = SpamFilter(5)
transactions: Transactions = Transactions()

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

block: Block = Block(
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
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)

data = Data(b"", b"")
svs: List[SignedVerification] = []
packets: List[VerificationPacket] = []
for d in range(0, 3):
  if d == 0:
    data = Data(bytes(32), edPubKey.to_bytes())
  else:
    data = Data(data.hash, edPubKey.to_bytes())
  data.sign(edPrivKey)
  data.beat(dataFilter)
  transactions.add(data)

  svs.append(SignedVerification(data.hash))
  svs[-1].sign(0, blsPrivKey)
  packets.append(VerificationPacket(data.hash, [0]))

block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents(packets),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packets),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packets, [], Signature.aggregate([svs[0].signature, svs[1].signature, svs[2].signature]))
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)

vectors: IO[Any] = open("e2e/Vectors/Merit/HundredSeventyFive.json", "w")
vectors.write(json.dumps({
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON(),
  "verification": svs[0].toSignedJSON()
}))
vectors.close()
