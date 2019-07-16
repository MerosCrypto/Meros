# pyright: strict

#Merit libs.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#Time lib.
import time

#JSON lib.
import json

#Blockchain.
blockchain = Blockchain(
    b"MEROS_DEVELOPER_TESTNET_2",
    600,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)

#Generate blocks.
for i in range(1, 26):
    #Create the Block.
    block = Block(
        BlockHeader(
            i,
            blockchain.last(),
            int(time.time())
        ),
        BlockBody()
    )

    #Mine it.
    block.header.rehash()
    while int.from_bytes(block.header.hash, "big") < blockchain.difficulty:
        block.header.proof += 1
        block.header.rehash()

    #Add it locally.
    blockchain.add(block)
    print("Generated Blank Block " + str(i) + ".")

result = []
for b in range(1, len(blockchain.blocks)):
    result.append(blockchain.blocks[b].toJSON())
vectors = open("python_tests/Vectors/BlankBlocks.json", "w")
vectors.write(json.dumps(result))
vectors.close()
