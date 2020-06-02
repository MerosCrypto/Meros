#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Transactions classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Verification classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
blockchain: Blockchain = Blockchain()
#Transactions.
transactions: Transactions = Transactions()

#Spam Filter.
spamFilter: SpamFilter = SpamFilter(5)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest()),
  PrivateKey(blake2b(b'\2', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [
  blsPrivKeys[0].toPublicKey(),
  blsPrivKeys[1].toPublicKey(),
  blsPrivKeys[2].toPublicKey()
]

#Give the first key 5 Blocks of Merit.
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
for _ in range(5):
  #Mine it.
  block.mine(blsPrivKeys[0], blockchain.difficulty())

  #Add it.
  blockchain.add(block)
  print("Generated Hundred Two Block " + str(len(blockchain.blocks)) + ".")

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

#Give the second key 80 Blocks of Merit.
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
for _ in range(80):
  block.mine(blsPrivKeys[1], blockchain.difficulty())
  blockchain.add(block)
  print("Generated Hundred Two Block " + str(len(blockchain.blocks)) + ".")

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

#Give the third key 14 Blocks of Merit.
block: Block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKeys[2].serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
for _ in range(14):
  block.mine(blsPrivKeys[2], blockchain.difficulty())
  blockchain.add(block)
  print("Generated Hundred Two Block " + str(len(blockchain.blocks)) + ".")

  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      2,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

#Create a Data and verify it with the first and second holders.
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
packets: List[VerificationPacket] = [VerificationPacket(data.hash, [0, 1])]

block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents(packets),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packets),
    2,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packets, [], Signature.aggregate([verifs[0].signature, verifs[1].signature]))
)

#Also mine enough Blocks to close out the Epoch.
for _ in range(6):
  block.mine(blsPrivKeys[2], blockchain.difficulty())
  blockchain.add(block)
  print("Generated Hundred Two Block " + str(len(blockchain.blocks)) + ".")

  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      2,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

#Save the Blockchain and Transactions DAG.
result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/HundredTwo.json", "w")
vectors.write(json.dumps(result))
vectors.close()
