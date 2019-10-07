#Types.
from typing import IO, Any

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

#Miner Private Key.
privKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')

#Create the Block.
block: Block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        bytes(48),
        bytes(48),
        privKey.get_public_key().serialize(),
        int(time())
    ),
    BlockBody()
)

#Generate blocks.
for i in range(1, 26):
    #Mine the Block.
    block.mine(privKey, blockchain.difficulty())

    #Add it locally.
    blockchain.add(block)
    print("Generated Blank Block " + str(i) + ".")

    #Create the next Block.
    block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            bytes(48),
            bytes(48),
            0,
            int(time())
        ),
        BlockBody()
    )

vectors: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
