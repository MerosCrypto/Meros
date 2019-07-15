#Time lib.
import time

#Merit libs.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#RPC lib.
from python_tests.RPC.RPC import RPC

#Blockchain.
blockchain = Blockchain(
    b"MEROS_DEVELOPER_TESTNET_2",
    600,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)
#RPC.
rpc = RPC()

#Add ten blocks.
for i in range(1, 11):
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

    #Add it to the node.
    rpc.call("merit", "publishBlock", [block.serialize().hex()])

    #Verify the difficulty.
    if blockchain.difficulty != int(rpc.call("merit", "getDifficulty", [0])["difficulty"], 16):
        raise Exception("difficulty doesn't match.")

    nodeBlock = rpc.call("merit", "getBlock", [i])

    if nodeBlock["header"]["nonce"] != block.header.nonce:
        raise Exception("Nonce doesn't match.")
    if nodeBlock["header"]["hash"] != block.header.hash.hex().upper():
        raise Exception("Hash doesn't match.")
    if nodeBlock["header"]["last"] != block.header.last.hex().upper():
        raise Exception("Last doesn't match.")

    if nodeBlock["header"]["aggregate"] != block.header.aggregate.hex().upper():
        raise Exception("Aggregate doesn't match.")
    if nodeBlock["header"]["miners"] != block.header.miners.hex().upper():
        raise Exception("Miners hash doesn't match.")

    if nodeBlock["header"]["time"] != block.header.time:
        raise Exception("Time doesn't match.")
    if nodeBlock["header"]["proof"] != block.header.proof:
        raise Exception("Proof doesn't match.")

    if len(nodeBlock["miners"]) != len(block.body.miners):
        raise Exception("Miners doesn't match.")
    for i in range(0, len(block.body.miners)):
        if nodeBlock["miners"][i]["miner"] != block.body.miners[i][0].serialize().hex().upper():
            raise Exception("Miners doesn't match.")
        if nodeBlock["miners"][i]["amount"] != block.body.miners[i][1]:
            raise Exception("Miners doesn't match.")

if rpc.call("merit", "getHeight")["height"] != 11:
    raise Exception("Height doesn't match.")
