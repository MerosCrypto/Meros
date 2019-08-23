#Types.
from typing import IO, Any

#Merit classes.
from python_tests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from python_tests.Tests.Errors import TestError

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#Merit verifier.
from python_tests.Tests.Merit.Verify import verifyBlockchain

#JSON standard lib.
import json

def MSyncTest(
    rpc: RPC
) -> None:
    #Blockchain.
    file: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        json.loads(file.read())
    )
    file.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(blockchain.blocks)
    )

    sentLast: bool = False
    hash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.last())
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    if block.header.hash == blockchain.blocks[len(blockchain.blocks) - 2].header.hash:
                        sentLast = True
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            if sentLast:
                break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(rpc, blockchain)

    #Playback their messages.
    rpc.meros.playback()
