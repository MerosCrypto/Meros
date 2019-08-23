#Tests proper creation and handling of multiple MeritRemovals when Meros receives multiple causes for a MeritRemoval.

#Types.
from typing import Dict, IO, Any

#Data class.
from python_tests.Classes.Transactions.Data import Data

#SignedMeritRemoval class.
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Blockchain class.
from python_tests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from python_tests.Tests.Errors import TestError

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#Merit and Consensus verifiers.
from python_tests.Tests.Merit.Verify import verifyBlockchain
from python_tests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def MRMCauseTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/Multiple.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    #Data.
    data: Data = Data.fromJSON(vectors["data"])
    #MeritRemovals.
    mr1: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal1"])
    mr2: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal2"])
    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )
    file.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(blockchain.blocks) - 1
    )

    hash: bytes = bytes()
    msg: bytes = bytes()
    height: int = 0
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.blocks[1].header.hash)
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
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Send the Data.
    if rpc.meros.transaction(data) != rpc.meros.recv():
        raise TestError("Unexpected message sent.")

    #Send the first SignedElement.
    if rpc.meros.signedElement(mr1.se1) != rpc.meros.recv():
        raise TestError("Unexpected message sent.")
    #Send the second.
    rpc.meros.signedElement(mr1.se2)

    #Verify the first MeritRemoval.
    if rpc.meros.recv() != (MessageType.SignedMeritRemoval.toByte() + mr1.signedSerialize()):
        raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 100, mr1, True)

    #Send the third SignedElement.
    rpc.meros.signedElement(mr2.se2)

    #Meros should treat the first created MeritRemoval as the default MeritRemoval.
    if rpc.meros.recv() != (MessageType.SignedMeritRemoval.toByte() + mr1.signedSerialize()):
        raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 100, mr1, True)

    #Send the final Block which archived the second MeritRemoval.
    rpc.meros.blockHeader(blockchain.blocks[-1].header)
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
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
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(rpc, blockchain)

    #Verify the MeritRemoval was corrected.
    verifyMeritRemoval(rpc, 1, 100, mr2, False)
