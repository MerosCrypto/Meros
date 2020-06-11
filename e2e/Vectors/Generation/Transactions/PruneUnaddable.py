from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Blockchain

blockchain: Blockchain = Blockchain()
dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Generate a Block granting the holder Merit.
block = Block(
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
print("Generated Prune Unaddable Block " + str(len(blockchain.blocks)) + ".")

#Create the original Data.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
datas[0].sign(edPrivKey)
datas[0].beat(dataFilter)

#Verify it.
verifs: List[SignedVerification] = [SignedVerification(datas[0].hash)]
verifs[0].sign(0, blsPrivKey)

#Create two competing Datas yet only verify the first.
for d in range(2):
  datas.append(Data(datas[0].hash, d.to_bytes(1, "big")))
  datas[1 + d].sign(edPrivKey)
  datas[1 + d].beat(dataFilter)

verifs.append(SignedVerification(datas[1].hash))
verifs[1].sign(0, blsPrivKey)

#Create a Data that's a descendant of the Data which will be beaten.
datas.append(Data(datas[2].hash, (2).to_bytes(1, "big")))
datas[3].sign(edPrivKey)
datas[3].beat(dataFilter)

#Create a SignedVerification for the descendant Data.
descendantVerif: SignedVerification = SignedVerification(datas[1].hash)
descendantVerif.sign(0, blsPrivKey)

#Convert the Verifications to packets.
packets: List[VerificationPacket] = [
  VerificationPacket(verifs[0].hash, [0]),
  VerificationPacket(verifs[1].hash, [0])
]

#Generate another 6 Blocks.
#Next block should have the packets.
block: Block = Block(
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
  BlockBody(packets, [], Signature.aggregate([verifs[0].signature, verifs[1].signature]))
)
for _ in range(6):
  #Mine it.
  block.mine(blsPrivKey, blockchain.difficulty())

  #Add it.
  blockchain.add(block)
  print("Generated Prune Unaddable Block " + str(len(blockchain.blocks)) + ".")

  #Create the next Block.
  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON(), datas[3].toJSON()],
  "verification": descendantVerif.toSignedJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Transactions/PruneUnaddable.json", "w")
vectors.write(json.dumps(result))
vectors.close()
