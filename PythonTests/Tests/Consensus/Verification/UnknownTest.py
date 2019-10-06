"""
#Tests proper handling of Verifications with Transactions which don't exist.

#Types.
from typing import Dict, IO, Any

#SignedVerification class.
from PythonTests.Classes.Consensus.Verification import SignedVerification

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#JSON standard lib.
import json

def VUnknownTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Parsable.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    #SignedVerification.
    sv: SignedVerification = SignedVerification.fromJSON(vectors["verification"])
    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )
    file.close()

    #Handshake with the node.
    rpc.meros.connect(254, 254, len(blockchain.blocks))

    sentLast: bool = False
    reqHash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.last())
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            reqHash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            reqHash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            rpc.meros.element(sv)

        elif MessageType(msg[0]) == MessageType.TransactionRequest:
            sentLast = True
            rpc.meros.dataMissing()

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            if sentLast:
                break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Verification and Block were not added.
    if rpc.call("consensus", "getHeight", [sv.holder.hex()]) != 0:
        raise TestError("Meros added an unknown Verification.")

    if rpc.call("merit", "getHeight") != 2:
        raise TestError("Meros added a Block with an unknown Verification.")
"""
