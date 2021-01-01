from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket
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

blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [
  blsPrivKeys[0].toPublicKey(),
  blsPrivKeys[1].toPublicKey()
]

for i in range(4):
  merit.add(Block.fromJSON(blankBlocks[i]))

#Add a Block to another verifier.
block: Block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    bytes(32),
    0,
    bytes(4),
    bytes(32),
    blsPubKeys[1].serialize(),
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(blsPrivKeys[1], merit.blockchain.difficulty())
merit.add(block)

#Create a Data.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)

#Verify it with both holders.
verifs: List[SignedVerification] = [SignedVerification(data.hash), SignedVerification(data.hash)]
for v in range(2):
  verifs[v].sign(v, blsPrivKeys[v])

#Create the packets.
packet: SignedVerificationPacket = SignedVerificationPacket(
  data.hash,
  [0, 1],
  Signature.aggregate([verifs[0].signature, verifs[1].signature])
)

#Create a Block containing the packet.
block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    BlockHeader.createContents([packet]),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), [packet]),
    0,
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([packet], [], packet.signature)
)
block.mine(blsPrivKeys[0], merit.blockchain.difficulty())
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
      1,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(blsPrivKeys[1], merit.blockchain.difficulty())
  merit.add(block)

#Split the chain at this point.
#One Blockchain should use a Claim signed by key 0.
#One Blockchain should use a Claim signed by key 1.
merits: List[Merit] = [Merit.fromJSON(merit.toJSON()) for _ in range(2)]

for m in range(2):
  #Create the Claim.
  claim: Claim = Claim(
    [(merit.mints[0], 0), (merit.mints[0], 1)],
    edPubKey.to_bytes()
  )
  claim.sign(blsPrivKeys[m])
  transactions.add(claim)

  #Verify the Claim.
  sv: SignedVerification = SignedVerification(claim.hash)
  sv.sign(0, blsPrivKeys[0])
  packet = SignedVerificationPacket(claim.hash, [0], sv.signature)

  #Archive it.
  block = Block(
    BlockHeader(
      0,
      merit.blockchain.last(),
      BlockHeader.createContents([packet]),
      1,
      bytes(4),
      BlockHeader.createSketchCheck(bytes(4), [packet]),
      0,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([packet], [], packet.signature)
  )
  block.mine(blsPrivKeys[0], merit.blockchain.difficulty())
  merits[m].add(block)

with open("e2e/Vectors/Transactions/DifferentMeritHolderClaim.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchains": [merits[0].toJSON(), merits[1].toJSON()],
    "transactions": transactions.toJSON()
  }))
