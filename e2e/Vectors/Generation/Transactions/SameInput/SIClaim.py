from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Merit

bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blankBlocks: List[Dict[str, Any]] = json.loads(bbFile.read())
bbFile.close()

transactions: Transactions = Transactions()
merit: Merit = Merit()
dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

merit.add(Block.fromJSON(blankBlocks[0]))

#Create the Data.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)

#Verify it.
verif: SignedVerification = SignedVerification(data.hash)
verif.sign(0, blsPrivKey)
packet: List[VerificationPacket] = [VerificationPacket(data.hash, [0])]

block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    BlockHeader.createContents(packet),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packet),
    0,
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packet, [], verif.signature)
)
block.mine(blsPrivKey, merit.blockchain.difficulty())
merit.add(block)

#Generate another 5 Blocks to close the Epochs.
for _ in range(5):
  block = Block(
    BlockHeader(
      0,
      merit.blockchain.last(),
      bytes(32),
      0,
      bytes(4),
      bytes(32),
      0,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(blsPrivKey, merit.blockchain.difficulty())
  merit.add(block)

#Create the Claim.
claim: Claim = Claim(
  [(merit.mints[0], 0), (merit.mints[0], 0)],
  edPubKey.to_bytes()
)
claim.sign(blsPrivKey)
transactions.add(claim)

#Archive it on the Blockchain.
verif: SignedVerification = SignedVerification(claim.hash)
verif.sign(0, blsPrivKey)

packet: List[VerificationPacket] = [VerificationPacket(claim.hash, [0])]
block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    BlockHeader.createContents(packet),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packet),
    0,
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packet, [], verif.signature)
)
block.mine(blsPrivKey, merit.blockchain.difficulty())
merit.add(block)

with open("e2e/Vectors/Transactions/SameInput/Claim.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.blockchain.toJSON(),
    "transactions": transactions.toJSON()
  }))
