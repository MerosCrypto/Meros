#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey

#SendDifficulty class.
from PythonTests.Classes.Consensus.SendDifficulty import SignedSendDifficulty

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
bbFile: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain: Blockchain = Blockchain.fromJSON(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
    blocks
)
bbFile.close()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=48).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create a SendDifficulty.
sendDiff: SignedSendDifficulty = SignedSendDifficulty(bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"), 0)
sendDiff.sign(0, blsPrivKey)

#Generate a Block containing the SendDifficulty.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([], [sendDiff.toSignedElement()]),
        1,
        bytes(4),
        bytes(48),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [sendDiff.toSignedElement()], sendDiff.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Mine 24 more Blocks until there's a vote.
for _ in range(24):
    block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            bytes(48),
            1,
            bytes(4),
            bytes(48),
            0,
            blockchain.blocks[-1].header.time + 1200
        ),
        BlockBody()
    )
    #Mine it.
    block.mine(blsPrivKey, blockchain.difficulty())

    #Add it.
    blockchain.add(block)
    print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Now that we have aa vote, update our vote.
sendDiff = SignedSendDifficulty(bytes.fromhex("888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888"), 1)
sendDiff.sign(0, blsPrivKey)

#Generate a Block containing the new SendDifficulty.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([], [sendDiff.toSignedElement()]),
        1,
        bytes(4),
        bytes(48),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [sendDiff.toSignedElement()], sendDiff.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/Difficulties/SendDifficulty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
