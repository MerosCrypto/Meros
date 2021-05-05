from typing import List
import json

import e2e.Libs.Ristretto.ed25519 as ed25519

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Block import BlockHeader, BlockBody, Block
from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock

blsPrivKey: PrivateKey = PrivateKey(0)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

dataFilter: SpamFilter = SpamFilter(5)

#Create a Block to earn Merit.
blocks: List[Block] = []
blocks.append(PrototypeBlock(1200, minerID=blsPrivKey).finish(0, Merit()))

#Create five Datas and matching Verifications.
#The test only sends a couple of the Verifications; that said, it's easy to generate the Block signature thanks to this.
txs: List[Data] = [Data(bytes(32), edPubKey)]
verifs: List[SignedVerification] = []
for i in range(5):
  txs[-1].sign(edPrivKey)
  txs[-1].beat(dataFilter)

  verifs.append(SignedVerification(txs[-1].hash))
  verifs[-1].sign(0, blsPrivKey)
  txs.append(Data(txs[-1].hash, b"\0"))
del txs[-1]

#Create the final Block.
#Done manually as it has invalid data.
packets: List[VerificationPacket] = [VerificationPacket(tx.hash, [0]) for tx in txs]
blocks.append(
  Block(
    BlockHeader(
      0,
      blocks[0].header.hash,
      BlockHeader.createContents(packets),
      4,
      bytes(4),
      BlockHeader.createSketchCheck(bytes(4), packets),
      0,
      2400
    ),
    BlockBody(packets, [], Signature.aggregate([verif.signature for verif in verifs]))
  )
)
#The difficulty either shouldn't change or should lower, hence why this works.
blocks[-1].header.mine(blsPrivKey, Merit().blockchain.difficulty())

#Only save the Verifications the test will use.
#Not a micro-opt on disk space; rather ensures this data isn't floating around to cause invalid testing methodology.
#This would optimally be inlined below with the vector write, yet pylint errors on the complex statement.
verifs = verifs[:2]

with open("e2e/Vectors/Merit/TwoHundredSeventyFour/MatchesHeaderQuantity.json", "w") as vectors:
  vectors.write(json.dumps({
    "blocks": [block.toJSON() for block in blocks],
    "transactions": [tx.toJSON() for tx in txs],
    "verifications": [verif.toSignedJSON() for verif in verifs]
  }))
