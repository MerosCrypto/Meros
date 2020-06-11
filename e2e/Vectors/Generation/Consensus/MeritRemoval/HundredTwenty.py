from typing import Dict, IO, Any

from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

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
print("Generated Hundred Twenty Block " + str(len(blockchain.blocks)) + ".")

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(3, 0)
dataDiff.sign(0, blsPrivKey)

#Create a conflicting DataDifficulty with the same nonce.
dataDiffConflicting = SignedDataDifficulty(1, 0)
dataDiffConflicting.sign(0, blsPrivKey)

#Generate a Block containing the competing Data difficulty.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [dataDiffConflicting]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [dataDiffConflicting], dataDiffConflicting.signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated Hundred Twenty Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "mempoolDataDiff": dataDiff.toSignedJSON(),
  "blockchainDataDiff": dataDiffConflicting.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwenty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
