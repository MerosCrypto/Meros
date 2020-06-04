#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#Element classes.
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Blockchain classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Blockchains.
blockchain: Blockchain = Blockchain()

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
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Twenty Three Swap Block " + str(len(blockchain.blocks)) + ".")

#Create conflicting Data Difficulties.
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(3, 0),
  SignedDataDifficulty(4, 0)
]
dataDiffs[0].sign(0, blsPrivKey)
dataDiffs[1].sign(0, blsPrivKey)

#Create a MeritRemoval out of the conflicting Data Difficulties.
mr: SignedMeritRemoval = SignedMeritRemoval(dataDiffs[0], dataDiffs[1])

#Generate a Block containing the MeritRemoval.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [mr]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [mr], mr.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Twenty Three Swap Block " + str(len(blockchain.blocks)) + ".")

#Create a MeritRemoval with the Elements swapped.
swapped: SignedMeritRemoval = SignedMeritRemoval(dataDiffs[1], dataDiffs[0])

#Generate a Block containing the swapped MeritRemoval.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [swapped]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [swapped], swapped.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Twenty Three Swap Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Swap.json", "w")
vectors.write(json.dumps(result))
vectors.close()
