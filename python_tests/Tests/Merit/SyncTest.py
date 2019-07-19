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

    msgs: List[bytes] = []
    ress: List[bytes] = []
    sentLast: bool = False
    while True:
        msgs.append(rpc.meros.recv())

        if MessageType(msgs[-1][0]) == MessageType.Syncing:
            ress.append(rpc.meros.acknowledgeSyncing())

        elif MessageType(msgs[-1][0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msgs[-1][1 : 5], byteorder="big")
            if height == 0:
                ress.append(rpc.meros.blockHash(blockchain.last()))
            else:
                if height >= len(blockchain.blocks):
                    raise Exception("Meros asked for a Block Hash we do not have.")

                ress.append(rpc.meros.blockHash(blockchain.blocks[height].header.hash))

        elif MessageType(msgs[-1][0]) == MessageType.BlockHeaderRequest:
            hash: bytes = msgs[-1][1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockHeader(block.header))
                    break

                if block.header.hash == blockchain.last():
                    raise Exception("Meros asked for a Block Header we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.BlockBodyRequest:
            hash: bytes = msgs[-1][1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockBody(block.body))
                    if block.header.hash == blockchain.blocks[len(blockchain.blocks) - 2].header.hash:
                        sentLast = True
                    break

                if block.header.hash == blockchain.last():
                    raise Exception("Meros asked for a Block Nody we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.SyncingOver:
            ress.append(b'\xFF')
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

    #Replay their messages and verify they sent what we sent.
    for m in range(0, len(msgs)):
        rpc.meros.send(msgs[m])
        if ress[m] != b'\xFF':
            if ress[m] != rpc.meros.recv():
                raise Exception("Invalid sync response.")
