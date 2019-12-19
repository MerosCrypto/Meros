#Types.
from typing import List, IO, Any

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

#Miner Private Keys.
privKeys: List[PrivateKey] = [
    PrivateKey(blake2b(b'\0', digest_size=48).digest()),
    PrivateKey(blake2b(b'\1', digest_size=48).digest()),
    PrivateKey(blake2b(b'\2', digest_size=48).digest()),
    PrivateKey(blake2b(b'\3', digest_size=48).digest()),
    PrivateKey(blake2b(b'\4', digest_size=48).digest())
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
            privKeys[i - 1].toPublicKey().serialize(),
            blockchain.blocks[-1].header.time + 1200
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
            blockchain.blocks[-1].header.time + 1200
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
