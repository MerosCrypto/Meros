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

#JSON standard lib.
import json

#Verify a MeritRemoval over the RPC.
def verifyMeritRemoval(
    rpc: RPC,
    removal: PartiallySignedMeritRemoval,
    malicious: bool
) -> None:
    #Verify the Merit Holder height.
    if rpc.call("consensus", "getHeight", [removal.holder.hex()]) != 2:
        raise TestError("Merit Holder height doesn't match.")

    #Verify the MeritRemoval.
    mrJSON: Dict[str, Any] = rpc.call("consensus", "getElement", [
        removal.holder.hex(),
        1
    ])
    if malicious:
        if mrJSON["nonce"] != 0:
            raise TestError("MeritRemoval nonce is invalid.")
        mrJSON["nonce"] = 1
    if mrJSON != removal.toJSON():
        raise TestError("Merit Removal doesn't match.")

    #Verify the Total Merit.
    if rpc.call("merit", "getTotalMerit") != 200 if malicious else 0:
        raise TestError("Total Merit doesn't match.")

    #Verify the Live Merit.
    if rpc.call("merit", "getLiveMerit", [removal.holder.hex()]) != 200 if malicious else 0:
        raise TestError("Live Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [removal.holder.hex()]) != {
        "live": True,
        "malicious": malicious,
        "merit": 200 if malicious else 0
    }:
        raise TestError("Merit Holder's Merit doesn't match.")

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
    verifyMeritRemoval(rpc, removal, True)

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

    #Verify the height.
    if rpc.call("merit", "getHeight") != len(merit.blockchain.blocks):
        raise TestError("Height doesn't match.")

    #Verify the difficulty.
    if merit.blockchain.difficulty != int(rpc.call("merit", "getDifficulty"), 16):
        raise TestError("Difficulty doesn't match.")

    #Verify the blocks.
    for block in merit.blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise TestError("Block doesn't match.")

    #Verify the Consensus
    for pubKey in consensus.holders:
        for e in range(0, len(consensus.holders[pubKey])):
            if rpc.call("consensus", "getElement", [
                pubKey.hex(),
                e
            ]) != consensus.holders[pubKey][e].toJSON():
                raise TestError("Element doesn't match.")

    #Verify the MeritRemoval again.
    verifyMeritRemoval(rpc, removal, False)
