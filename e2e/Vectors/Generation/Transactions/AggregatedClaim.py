#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

#Transactions classes.
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from e2e.Classes.Consensus.SpamFilter import SpamFilter

#SignedVerification and VerificationPacket classes.
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket

#Merit classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Merit

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blank Blocks.
bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blankBlocks: List[Dict[str, Any]] = json.loads(bbFile.read())
bbFile.close()

#Transactions.
transactions: Transactions = Transactions()
#Merit.
merit: Merit = Merit()

#SpamFilter.
dataFilter: SpamFilter = SpamFilter(5)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [
  blsPrivKeys[0].toPublicKey(),
  blsPrivKeys[1].toPublicKey()
]

#Add 4 Blank Blocks.
for i in range(4):
  merit.add(Block.fromJSON(blankBlocks[i]))

#Add a 5th Block to another verifier.
block: Block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKeys[1].serialize(),
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
#Mine it.
block.mine(blsPrivKeys[1], merit.blockchain.difficulty())

#Add it.
merit.add(block)
print("Generated Aggregated Claim Block " + str(len(merit.blockchain.blocks) - 1) + ".")

#Create the Datas.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
datas.append(Data(datas[-1].hash, bytes(1)))
datas.append(Data(datas[-1].hash, bytes(1)))
datas.append(Data(datas[-1].hash, bytes(1)))
for data in datas:
  data.sign(edPrivKey)
  data.beat(dataFilter)
  transactions.add(data)

#Verify them.
verifs: List[List[SignedVerification]] = []
for data in datas:
  verifs.append([SignedVerification(data.hash), SignedVerification(data.hash)])
  for v in range(2):
    verifs[-1][v].sign(v, blsPrivKeys[v])

#Create the packets.
packets: List[SignedVerificationPacket] = []
for packet in verifs:
  packets.append(
    SignedVerificationPacket(
      packet[0].hash,
      [0, 1],
      Signature.aggregate([packet[0].signature, packet[1].signature])
    )
  )

#Create Blocks containing these packets.
for packet in packets:
  block = Block(
    BlockHeader(
      0,
      merit.blockchain.last(),
      BlockHeader.createContents([packet]),
      1,
      bytes(4),
      BlockHeader.createSketchCheck(bytes(4), [packet]),
      1,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([packet], [], packet.signature)
  )
  block.mine(blsPrivKeys[1], merit.blockchain.difficulty())
  merit.add(block)
  print("Generated Aggregated Claim Block " + str(len(merit.blockchain.blocks) - 1) + ".")

#Generate another 5 Blocks to close the Epochs.
#Next block should have the packet.
for _ in range(5):
  block = Block(
    BlockHeader(
      0,
      merit.blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(blsPrivKeys[0], merit.blockchain.difficulty())
  merit.add(block)
  print("Generated Aggregated Claim Block " + str(len(merit.blockchain.blocks) - 1) + ".")

#Create three Claims.
#Other tests test the basic Claim X format.
#We need to test XX, XY, and XYY.
claims: List[Claim] = [
  #XX.
  Claim(
    [(merit.mints[0].hash, 0), (merit.mints[1].hash, 0)],
    edPubKey.to_bytes()
  ),
  #XY.
  Claim(
    [(merit.mints[2].hash, 0), (merit.mints[0].hash, 1)],
    edPubKey.to_bytes()
  ),
  #XYY.
  Claim(
    [(merit.mints[3].hash, 0), (merit.mints[1].hash, 1), (merit.mints[2].hash, 1)],
    edPubKey.to_bytes()
  )
]
claims[0].amount = merit.mints[0].outputs[0][1] + merit.mints[1].outputs[0][1]
claims[1].amount = merit.mints[2].outputs[0][1] + merit.mints[0].outputs[1][1]
claims[2].amount = merit.mints[3].outputs[0][1] + merit.mints[1].outputs[1][1] + merit.mints[2].outputs[1][1]

claims[0].sign([blsPrivKeys[0], blsPrivKeys[0]])
claims[1].sign([blsPrivKeys[0], blsPrivKeys[1]])
claims[2].sign([blsPrivKeys[0], blsPrivKeys[1], blsPrivKeys[1]])
for claim in claims:
  transactions.add(claim)

#Verify the Claims.
verifs = []
for claim in claims:
  verifs.append([SignedVerification(claim.hash), SignedVerification(claim.hash)])
  for v in range(2):
    verifs[-1][v].sign(v, blsPrivKeys[v])

#Create the packets.
packets: List[SignedVerificationPacket] = []
for packet in verifs:
  packets.append(
    SignedVerificationPacket(
      packet[0].hash,
      [0, 1],
      Signature.aggregate([packet[0].signature, packet[1].signature])
    )
  )

#Create Blocks containing these packets.
for packet in packets:
  block = Block(
    BlockHeader(
      0,
      merit.blockchain.last(),
      BlockHeader.createContents([packet]),
      1,
      bytes(4),
      BlockHeader.createSketchCheck(bytes(4), [packet]),
      1,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([packet], [], packet.signature)
  )
  block.mine(blsPrivKeys[1], merit.blockchain.difficulty())
  merit.add(block)
  print("Generated Aggregated Claim Block " + str(len(merit.blockchain.blocks) - 1) + ".")

result: Dict[str, Any] = {
  "blockchain": merit.blockchain.toJSON(),
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Transactions/AggregatedClaim.json", "w")
vectors.write(json.dumps(result))
vectors.close()
