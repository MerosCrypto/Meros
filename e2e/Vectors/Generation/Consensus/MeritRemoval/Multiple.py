from typing import Dict, IO, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

blockchain: Blockchain = Blockchain()

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
print("Generated Multiple Block " + str(len(blockchain.blocks)) + ".")

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(3, 0)
dataDiff.sign(0, blsPrivKey)

#Create a conflicting DataDifficulty with the same nonce.
dataDiffConflicting: SignedDataDifficulty = SignedDataDifficulty(1, 0)
dataDiffConflicting.sign(0, blsPrivKey)

#Create a MeritRemoval out of the two of them.
mr1: SignedMeritRemoval = SignedMeritRemoval(dataDiff, dataDiffConflicting)

#Generate a Block containing the MeritRemoval.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [mr1]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [mr1], mr1.signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated Multiple Block " + str(len(blockchain.blocks)) + ".")

#Create two more DataDifficulties with a different nonce.
dataDiff = SignedDataDifficulty(3, 1)
dataDiff.sign(0, blsPrivKey)
dataDiffConflicting = SignedDataDifficulty(1, 1)
dataDiffConflicting.sign(0, blsPrivKey)

#Create another MeritRemoval out of these two.
mr2: SignedMeritRemoval = SignedMeritRemoval(dataDiff, dataDiffConflicting)

#Generate a Block containing the second MeritRemoval.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [mr2]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [mr2], mr2.signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated Multiple Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "removals": [mr1.toSignedJSON(), mr2.toSignedJSON()]
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/Multiple.json", "w")
vectors.write(json.dumps(result))
vectors.close()
