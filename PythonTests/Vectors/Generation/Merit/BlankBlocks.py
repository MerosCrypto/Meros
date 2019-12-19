#Types.
from typing import IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
blockchain: Blockchain = Blockchain(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)

#Miner Private Key.
privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=48).digest())

#Create the Block.
block: Block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        bytes(48),
        1,
        bytes(4),
        bytes(48),
        privKey.toPublicKey().serialize(),
        blockchain.blocks[-1].header.time + 1200
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
            1,
            bytes(4),
            bytes(48),
            0,
            blockchain.blocks[-1].header.time + 1200
        ),
        BlockBody()
    )

vectors: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
