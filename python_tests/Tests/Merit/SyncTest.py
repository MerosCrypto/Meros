# pyright: strict

#Types.
from typing import Dict, List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#JSON lib.
import json

def SyncTest(
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

    #Add all the Blocks locally.
    for jsonBlock in blocks:
        blockchain.add(Block.fromJSON(jsonBlock))

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(blockchain.blocks)
    )

    sentLast: bool = False
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], byteorder="big")
            if height == 0:
                rpc.meros.blockHash(blockchain.last())
            else:
                if height >= len(blockchain.blocks):
                    raise Exception("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash: bytes = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise Exception("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash: bytes = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    if block.header.hash == blockchain.blocks[len(blockchain.blocks) - 2].header.hash:
                        sentLast = True
                    break

                if block.header.hash == blockchain.last():
                    raise Exception("Meros asked for a Block Nody we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            if sentLast:
                break

    #Verify the height.
    if rpc.call("merit", "getHeight")["height"] != len(blocks) + 1:
        raise Exception("Height doesn't match.")

    #Verify the difficulty.
    if blockchain.difficulty != int(rpc.call("merit", "getDifficulty", [0])["difficulty"], 16):
        raise Exception("Difficulty doesn't match.")

    #Verify the blocks.
    for jsonBlock in blocks:
        if rpc.call("merit", "getBlock", [jsonBlock["header"]["nonce"]]) != jsonBlock:
            raise Exception("Block doesn't match.")
