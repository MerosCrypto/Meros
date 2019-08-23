#Types.
from typing import IO, Any

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

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

#Generate blocks.
for i in range(1, 26):
    #Create the Block.
    block: Block = Block(
        BlockHeader(
            i,
            blockchain.last(),
            int(time())
        ),
        BlockBody()
    )
    block.mine(blockchain.difficulty)

    #Add it locally.
    blockchain.add(block)
    print("Generated Blank Block " + str(i) + ".")

vectors: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
