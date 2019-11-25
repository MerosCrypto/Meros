#Types.
from typing import List, IO, Any

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#BLS lib.
import blspy

#Time standard function.
from time import time

#JSON standard lib.
import json

#Blockchain.
blockchain: Blockchain = Blockchain(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)

#Miner Private Keys.
privKeys: List[blspy.PrivateKey] = [
    blspy.PrivateKey.from_seed(b'\0'),
    blspy.PrivateKey.from_seed(b'\1'),
    blspy.PrivateKey.from_seed(b'\2'),
    blspy.PrivateKey.from_seed(b'\3'),
    blspy.PrivateKey.from_seed(b'\4')
]

#Assign every Miner Merit.
for i in range(1, 6):
    #Create the Block.
    block: Block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            bytes(48),
            1,
            bytes(4),
            bytes(48),
            privKeys[i - 1].get_public_key().serialize(),
            int(time())
        ),
        BlockBody()
    )

    #Mine the Block.
    block.mine(privKeys[i - 1], blockchain.difficulty())

    #Add it locally.
    blockchain.add(block)
    print("Generated State Block " + str(i) + ".")

#Assign Miner 0 4 more Blocks of Merit.
for i in range(6, 10):
    #Create the Block.
    block: Block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            bytes(48),
            1,
            bytes(4),
            bytes(48),
            0,
            int(time())
        ),
        BlockBody()
    )

    #Mine the Block.
    block.mine(privKeys[0], blockchain.difficulty())

    #Add it locally.
    blockchain.add(block)
    print("Generated State Block " + str(i) + ".")

vectors: IO[Any] = open("PythonTests/Vectors/Merit/StateBlocks.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
