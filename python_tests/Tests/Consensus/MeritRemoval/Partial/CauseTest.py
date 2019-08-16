#Tests proper creation and handling of a MeritRemoval when Meros receives cause for a partial MeritRemoval.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.MeritRemoval import PartiallySignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit class.
from python_tests.Classes.Merit.Merit import Merit

#TestError Exception.
from python_tests.Tests.TestError import TestError

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
    partialFile: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/Partial.json", "r")
    partialVectors: Dict[str, Any] = json.loads(partialFile.read())
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    #MeritRemoval.
    removal: PartiallySignedMeritRemoval = PartiallySignedMeritRemoval.fromJSON(partialVectors["removal"])
    consensus.add(removal.e1)
    consensus.add(removal)
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        Transactions(),
        consensus,
        partialVectors["blockchain"]
    )
    partialFile.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        3
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
                rpc.meros.blockHash(merit.blockchain.blocks[2].header.hash)
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.blocks[3].header.hash:
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.blocks[3].header.hash:
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            if msg[1 : 49] != removal.holder:
                raise TestError("Meros asked for an Element from an unknown MeritHolder.")
            if int.from_bytes(msg[49 : 53], byteorder = "big") != 0:
                raise TestError("Meros asked for an Element not mentioned in a record.")

            rpc.meros.element(removal.e1)

        elif MessageType(msg[0]) == MessageType.TransactionRequest:
            sentLast = True
            rpc.meros.dataMissing()

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
    rpc.meros.blockHeader(merit.blockchain.blocks[-1].header)
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(merit.blockchain.last())
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(rpc, merit.blockchain)

    #Verify the MeritRemoval again.
    verifyMeritRemoval(rpc, 2, 200, removal, False)

    #Verify the Consensus.
    verifyConsensus(rpc, consensus)
