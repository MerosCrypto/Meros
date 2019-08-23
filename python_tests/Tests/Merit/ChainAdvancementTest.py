#Types.
from typing import Dict, List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from python_tests.Tests.Errors import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

#Merit verifier.
from python_tests.Tests.Merit.Verify import verifyBlockchain

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
    file: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    #Publish Blocks.
    for jsonBlock in blocks:
        #Parse the Block.
        block: Block = Block.fromJSON(jsonBlock)

        #Add it locally.
        blockchain.add(block)

        #Publish it.
        rpc.call("merit", "publishBlock", [block.serialize().hex()])

        #Verify the difficulty.
        if int(rpc.call("merit", "getDifficulty"), 16) != blockchain.difficulty:
            raise TestError("Difficulty doesn't match.")

    #Verify the Blockchain.
    verifyBlockchain(rpc, blockchain)
