#Tests proper creation and handling of a MeritRemoval when Meros receives cause for a partial MeritRemoval.

#Types.
from typing import Dict, IO, Any

#Data class.
from python_tests.Classes.Transactions.Data import Data

#Consensus classes.
from python_tests.Classes.Consensus.MeritRemoval import PartiallySignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from python_tests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from python_tests.Tests.Errors import TestError

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#Merit and Consensus verifiers.
from python_tests.Tests.Merit.Verify import verifyBlockchain
from python_tests.Tests.Consensus.Verify import verifyMeritRemoval, verifyConsensus

#JSON standard lib.
import json

def MRPCauseTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/Partial.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    #Data.
    data: Data = Data.fromJSON(vectors["data"])
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    #MeritRemoval.
    removal: PartiallySignedMeritRemoval = PartiallySignedMeritRemoval.fromJSON(vectors["removal"])
    consensus.add(removal.e1)
    consensus.add(removal)
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

    sentLast: bool = False
    hash: bytes = bytes()
    msg: bytes = bytes()
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.blocks[2].header.hash)
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

                if block.header.hash == blockchain.blocks[3].header.hash:
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == blockchain.blocks[3].header.hash:
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            if msg[1 : 49] != removal.holder:
                raise TestError("Meros asked for an Element from an unknown MeritHolder.")
            if int.from_bytes(msg[49 : 53], byteorder = "big") != 0:
                raise TestError("Meros asked for an Element not mentioned in a record.")

            rpc.meros.element(removal.e1)

        elif MessageType(msg[0]) == MessageType.TransactionRequest:
            sentLast = True
            if msg[1 : 49] != data.hash:
                raise TestError("Meros asked for a Transaction not mentioned.")
            rpc.meros.transaction(data)

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            if sentLast == True:
                break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Send the second Element.
    rpc.meros.signedElement(removal.se2)

    #Verify the MeritRemoval.
    msg = rpc.meros.recv()
    if msg != (MessageType.SignedMeritRemoval.toByte() + removal.signedSerialize()):
        raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 2, 200, removal, True)

    #Send the final Block.
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

    #Verify the MeritRemoval again.
    verifyMeritRemoval(rpc, 2, 200, removal, False)

    #Verify the Consensus.
    verifyConsensus(rpc, consensus)
