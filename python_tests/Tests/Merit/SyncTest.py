#Types.
from typing import List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#JSON standard lib.
import json

def SyncTest(
    rpc: RPC
) -> None:
    #Blockchain.
    bbFile: IO[Any] = open("python_tests/Vectors/BlankBlocks.json", "r")
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        json.loads(bbFile.read())
    )
    bbFile.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(blockchain.blocks)
    )

    msgs: List[bytes] = []
    ress: List[bytes] = []
    sentLast: bool = False
    hash: bytes = bytes()
    while True:
        msgs.append(rpc.meros.recv())

        if MessageType(msgs[-1][0]) == MessageType.Syncing:
            ress.append(rpc.meros.acknowledgeSyncing())

        elif MessageType(msgs[-1][0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msgs[-1][1 : 5], byteorder = "big")
            if height == 0:
                ress.append(rpc.meros.blockHash(blockchain.last()))
            else:
                if height >= len(blockchain.blocks):
                    raise Exception("Meros asked for a Block Hash we do not have.")

                ress.append(rpc.meros.blockHash(blockchain.blocks[height].header.hash))

        elif MessageType(msgs[-1][0]) == MessageType.BlockHeaderRequest:
            hash = msgs[-1][1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockHeader(block.header))
                    break

                if block.header.hash == blockchain.last():
                    raise Exception("Meros asked for a Block Header we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.BlockBodyRequest:
            hash = msgs[-1][1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockBody(block.body))
                    if block.header.hash == blockchain.blocks[len(blockchain.blocks) - 2].header.hash:
                        sentLast = True
                    break

                if block.header.hash == blockchain.last():
                    raise Exception("Meros asked for a Block Body we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.SyncingOver:
            ress.append(bytes())
            if sentLast:
                break

        else:
            raise Exception("Unexpected message sent: " + msgs[-1].hex().upper())

    #Verify the height.
    if rpc.call("merit", "getHeight")["height"] != len(blockchain.blocks):
        raise Exception("Height doesn't match.")

    #Verify the difficulty.
    if blockchain.difficulty != int(rpc.call("merit", "getDifficulty", [0])["difficulty"], 16):
        raise Exception("Difficulty doesn't match.")

    #Verify the blocks.
    for block in blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise Exception("Block doesn't match.")

    #Replay their messages and verify they sent what we sent.
    for m in range(0, len(msgs)):
        rpc.meros.send(msgs[m])
        if len(ress[m]) != 0:
            if ress[m] != rpc.meros.recv():
                raise Exception("Invalid sync response.")
