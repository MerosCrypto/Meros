# pyright: strict

#Types.
from typing import Dict, List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#RPC class.
from python_tests.Meros.RPC import RPC

#JSON lib.
import json

def ChainAdvancementTest(
    rpc: RPC
) -> None:
    #Blockchain.
    blockchain: Blockchain = Blockchain(
        b"MEROS_DEVELOPER_TESTNET_2",
        600,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
    )
    #Blocks.
    vectors: IO[Any] = open("python_tests/Vectors/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(vectors.read())
    vectors.close()

    #Add Blocks.
    for jsonBlock in blocks:
        #Create the Block.
        block: Block = Block.fromJSON(jsonBlock)

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
