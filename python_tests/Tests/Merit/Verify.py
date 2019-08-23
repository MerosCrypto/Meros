#Blockchain class.
from python_tests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from python_tests.Tests.Errors import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

#Verify the Blockchain.
def verifyBlockchain(
    rpc: RPC,
    blockchain: Blockchain
) -> None:
    #Verify the height.
    if rpc.call("merit", "getHeight") != len(blockchain.blocks):
        raise TestError("Height doesn't match.")

    #Verify the difficulty.
    if blockchain.difficulty != int(rpc.call("merit", "getDifficulty"), 16):
        raise TestError("Difficulty doesn't match.")

    #Verify the blocks.
    for block in blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise TestError("Block doesn't match.")
