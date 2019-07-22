#Types.
from typing import Dict, List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#RPC class.
from python_tests.Meros.RPC import RPC

#JSON standard lib.
import json

def ChainAdvancementTest(
    rpc: RPC
) -> None:
    #Blockchain.
    blockchain: Blockchain = Blockchain(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
    )
    #Blocks.
    bbFile: IO[Any] = open("python_tests/Vectors/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
    bbFile.close()

    #Publish Blocks.
    for jsonBlock in blocks:
        #Parse the Block.
        block: Block = Block.fromJSON(jsonBlock)

        #Add it locally.
        blockchain.add(block)

        #Publish it.
        rpc.call("merit", "publishBlock", [block.serialize().hex()])

        #Verify the difficulty.
        if blockchain.difficulty != int(rpc.call("merit", "getDifficulty", [0])["difficulty"], 16):
            raise Exception("Difficulty doesn't match.")

        #Verify the Block.
        if rpc.call("merit", "getBlock", [block.header.nonce]) != jsonBlock:
            raise Exception("Block doesn't match.")

    #Verify the height.
    if rpc.call("merit", "getHeight")["height"] != len(blocks) + 1:
        raise Exception("Height doesn't match.")
