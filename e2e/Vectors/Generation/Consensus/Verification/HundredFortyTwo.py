from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Blockchain

blockchain: Blockchain = Blockchain()
transactions: Transactions = Transactions()
spamFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [
  blsPrivKeys[0].toPublicKey(),
  blsPrivKeys[1].toPublicKey()
]

#Give the first key Merit.
block: Block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKeys[0].serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(blsPrivKeys[0], blockchain.difficulty())
blockchain.add(block)
print("Generated Hundred Forty Two Block " + str(len(blockchain.blocks)) + ".")

#Give the second key Merit.
block: Block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKeys[1].serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(blsPrivKeys[1], blockchain.difficulty())
blockchain.add(block)
print("Generated Hundred Forty Two Block " + str(len(blockchain.blocks)) + ".")

#Create a Data and verify it by both parties.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(spamFilter)
transactions.add(data)

verifs: List[SignedVerification] = [
  SignedVerification(data.hash),
  SignedVerification(data.hash)
]
verifs[0].sign(0, blsPrivKeys[0])
verifs[1].sign(1, blsPrivKeys[1])
packets: List[VerificationPacket] = [VerificationPacket(data.hash, [0])]

block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents(packets),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packets),
    1,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packets, [], verifs[0].signature)
)
for _ in range(6):
  block.mine(blsPrivKeys[1], blockchain.difficulty())
  blockchain.add(block)
  print("Generated Hundred Forty Two Block " + str(len(blockchain.blocks)) + ".")

  #Create the next Block.
  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      1,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

#Save the appended data (3 Blocks and 12 Sends).
result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON(),
  "verification": verifs[1].toSignedJSON(),
  "transaction": data.hash.hex().upper()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/Verification/HundredFortyTwo.json", "w")
vectors.write(json.dumps(result))
vectors.close()
