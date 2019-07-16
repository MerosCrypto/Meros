# pyright: strict

#Merit libs.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#RPC lib.
from python_tests.RPC.RPC import RPC

#JSON lib.
import json

#Blockchain.
blockchain = Blockchain(
    b"MEROS_DEVELOPER_TESTNET_2",
    600,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)
#Blocks.
vectors = open("python_tests/Vectors/BlankBlocks.json", "r")
blocks = json.loads(vectors.read())
vectors.close()
#RPC.
rpc = RPC()

#Add Blocks.
for jsonBlock in blocks:
    #Create the Block.
    block = Block.fromJSON(jsonBlock)

    #Add it locally.
    blockchain.add(block)

    #Add it to the node.
    rpc.call("merit", "publishBlock", [block.serialize().hex()])

    #Verify the difficulty.
    if blockchain.difficulty != int(rpc.call("merit", "getDifficulty", [0])["difficulty"], 16):
        raise Exception("Difficulty doesn't match.")

    if rpc.call("merit", "getBlock", [block.header.nonce]) != jsonBlock:
        raise Exception("Block doesn't match.")

if rpc.call("merit", "getHeight")["height"] != len(blocks) + 1:
    raise Exception("Height doesn't match.")
